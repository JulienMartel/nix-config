#!/usr/bin/env python3
"""Make the JS we patched be the JS that runs, and fail the build if it isn't.

Claude Code ships as a `bun build --compile` binary, and since 2.1.259 that
bundle carries a JSC BYTECODE CACHE beside every JS module — ~75 MB of it,
compiled from the same source and stored in its own arena at the front of the
`__BUN,__bun` section. bun runs the bytecode and never looks at the source, so
the two byte-preserving TUI patches beside this file kept applying cleanly and
kept doing nothing: the footer row and the chip strip came back, the statusline
payload lost `permission_mode`, and the build stayed green because a patch that
COUNTS its matches can only prove it edited the file, never that anything reads
what it edited.

So this script does both halves of the fix:

  1. Drops the bytecode for the modules we edited. bun's standalone module
     graph gives each module a `bytecode` StringPointer; zero it and bun falls
     back to parsing that module's embedded source — the copy our patches just
     rewrote. Exactly one module in a stock 2.1.259 already ships that way (an
     embedded Mach-O asset), so a zero-length `bytecode` is a shape bun already
     handles rather than one we invented. Only the modules actually containing
     an edit lose their cache; everything else still starts from bytecode.

  2. Replaces the patches' count guards with a liveness guard. For every
     edit the patch scripts recorded it re-reads the finished binary and
     asserts (a) the bytes at that offset are still the bytes the patch wrote,
     and (b) the module containing them has no bytecode left. Together those
     two facts say the edited source is what JSC will execute — the thing a
     match count cannot say, and the thing that was false for the whole of
     2.1.259. Any failure exits non-zero and fails the nix build.

Nothing here is hardcoded to a release. The `__BUN,__bun` section comes from
the Mach-O load commands; the module record array is found by its own shape
(entries whose `name` StringPointer resolves to a `/$bunfs/root/…` path,
repeating at a fixed stride); and the two fields we care about are identified
by what they point AT, not by a fixed offset inside the record:

  * `contents` is the field pointing at a module body (they all open with the
    `// @bun` banner bun writes), and
  * `bytecode` is the one field whose target starts with the same 4 bytes for
    every module in the bundle — the JSC cached-bytecode magic. The companion
    field next to it varies per module and is left alone; zeroing `bytecode`
    on its own is enough to send bun back to the source (verified by rendering
    the TUI headlessly with only that field cleared).

If a bun upgrade reshapes the graph, every one of those derivations fails
loudly with what it expected, rather than silently leaving the cache in place.

Usage: claude-bytecode-liveness.py <path-to-claude-binary> <edits-manifest>

The manifest is JSON Lines, one object per edit, written by the patch scripts:
{"patch": <script>, "site": <what was edited>, "offset": <byte offset in the
binary>, "bytes": <hex of what was written>}.
"""

import collections
import json
import struct
import sys

MH_MAGIC_64 = 0xFEEDFACF
LC_SEGMENT_64 = 0x19
BUN_TRAILER = b"\n---- Bun! ----\n"
NAME_PREFIXES = (b"/$bunfs/root/", b"B:/~BUN/root/")
MODULE_BANNER = b"// @bun"


def die(msg):
    sys.exit(f"claude-bytecode-liveness: {msg}")


def bun_section(data):
    """File offset and size of __BUN,__bun, straight from the load commands."""
    (magic,) = struct.unpack_from("<I", data, 0)
    if magic != MH_MAGIC_64:
        die(f"not a thin 64-bit little-endian Mach-O (magic {magic:#010x})")
    ncmds = struct.unpack_from("<I", data, 16)[0]
    pos = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, pos)
        if cmd == LC_SEGMENT_64:
            nsects = struct.unpack_from("<I", data, pos + 64)[0]
            sec = pos + 72
            for _ in range(nsects):
                sectname = data[sec : sec + 16].rstrip(b"\0")
                segname = data[sec + 16 : sec + 32].rstrip(b"\0")
                if (segname, sectname) == (b"__BUN", b"__bun"):
                    size, offset = struct.unpack_from("<QI", data, sec + 40)
                    return offset, size
                sec += 80
        pos += cmdsize
    die("no __BUN,__bun section — this is not a `bun build --compile` binary")


def module_blob(data):
    """Start offset of bun's serialized module graph, and its trailer offset.

    The section opens with a u64 counting the bytes from just after itself to
    the end of the trailer; checking it is a free confirmation that we found
    both ends of the same blob.
    """
    sec_off, sec_size = bun_section(data)
    trailer = data.rfind(BUN_TRAILER, sec_off, sec_off + sec_size)
    if trailer < 0:
        die("no bun trailer inside __BUN,__bun")
    blob = sec_off + 8
    declared = struct.unpack_from("<Q", data, sec_off)[0]
    if blob + declared != trailer + len(BUN_TRAILER):
        die(
            f"section header claims {declared} bytes from {blob}, but the "
            f"trailer ends at {trailer + len(BUN_TRAILER)} — the bun bundle "
            f"layout changed"
        )
    return blob, trailer


def strp(data, at):
    return struct.unpack_from("<II", data, at)


def find_records(data, blob, trailer):
    """The module record array: (start offset, stride, count).

    Records are found by their `name` field, the only one pointing at a
    `/$bunfs/root/…` string. Nothing in the blob is aligned, so this walks byte
    by byte — over the tail first, where bun has always parked the array, and
    over more of the blob only if that comes up empty. Every record holds two
    such pointers, so the stride is read from every OTHER anchor, and the phase
    is settled afterwards by whichever start makes `contents` resolve.
    """
    anchors = []
    for window in (1 << 20, 1 << 23, 1 << 26):
        lo = max(blob, trailer - window)
        anchors = []
        for at in range(lo, trailer - 8):
            off, ln = strp(data, at)
            if not 13 <= ln <= 512 or off >= trailer - blob:
                continue
            if data.startswith(NAME_PREFIXES, blob + off):
                anchors.append(at)
        if len(anchors) >= 8:
            break
    if len(anchors) < 8:
        die(f"found {len(anchors)} module-name pointers, expected hundreds")
    strides = collections.Counter(
        anchors[i + 2] - anchors[i] for i in range(len(anchors) - 2)
    )
    stride, votes = strides.most_common(1)[0]
    if votes < len(anchors) * 0.5:
        die(f"module records have no consistent stride (best {stride}: {votes} votes)")
    seen = set(anchors)
    starts = [a for a in anchors if a + stride in seen]
    if not starts:
        die("module-name pointers do not repeat at the stride")
    first = min(starts)
    count = 1
    while first + count * stride in seen:
        count += 1
    return first, stride, count


def field_offsets(data, blob, first, stride, count):
    """Which slot in a record is `contents`, and which is `bytecode`.

    `contents` points at a module body; every one of them opens with bun's
    `// @bun` banner. `bytecode` is the slot that points into the cache arena
    in front of the sources AND whose target starts with the same four bytes
    every time — JSC's cached-bytecode magic. Nothing else in the record is
    both non-degenerate and byte-identical at its head across the bundle.
    """
    slots = range(0, stride - 8 + 1, 4)
    records = [first + i * stride for i in range(count)]

    contents = [k for k in slots if _is_contents(data, blob, records, k)]
    if len(contents) != 1:
        die(f"expected exactly one `contents` field per record, found {contents}")
    contents = contents[0]

    arena_hi = min(strp(data, r + contents)[0] for r in records)
    candidates = {}
    for k in slots:
        if k == contents:
            continue
        heads, offsets = set(), set()
        for r in records:
            off, ln = strp(data, r + k)
            if ln == 0:
                continue
            if off == 0 or off + ln > arena_hi:
                break
            heads.add(bytes(data[blob + off : blob + off + 4]))
            offsets.add(off)
        else:
            if len(heads) == 1 and len(offsets) > 1:
                candidates[k] = heads.pop()
    if len(candidates) != 1:
        die(
            f"expected exactly one `bytecode` field per record, found "
            f"{sorted(candidates)} — the bun module record changed shape"
        )
    bytecode, magic = candidates.popitem()
    return contents, bytecode, magic


def _is_contents(data, blob, records, k):
    """True if slot k holds the module sources. A tenth of the bundle is
    embedded assets rather than JS and carries no banner, so this asks for a
    majority; no other slot in the record scores above zero."""
    banners = 0
    for r in records:
        off, ln = strp(data, r + k)
        if ln >= len(MODULE_BANNER) and data.startswith(MODULE_BANNER, blob + off):
            banners += 1
    return banners > len(records) * 0.5


def main():
    if len(sys.argv) != 3:
        die("usage: claude-bytecode-liveness.py <binary> <edits-manifest>")
    path, manifest = sys.argv[1], sys.argv[2]

    with open(path, "rb") as f:
        data = bytearray(f.read())

    try:
        with open(manifest, "r") as f:
            edits = [json.loads(line) for line in f if line.strip()]
    except FileNotFoundError:
        die(f"no edit manifest at {manifest} — the patch scripts did not run")
    if not edits:
        die(f"the edit manifest {manifest} is empty — the patch scripts made no edits")

    blob, trailer = module_blob(data)
    first, stride, count = find_records(data, blob, trailer)
    contents, bytecode, magic = field_offsets(data, blob, first, stride, count)

    # Map every edit onto the module whose source contains it.
    modules = {}
    for i in range(count):
        r = first + i * stride
        off, ln = strp(data, r + contents)
        modules[r] = (blob + off, blob + off + ln)

    hosts = {}
    for e in edits:
        at = e["offset"]
        for r, (lo, hi) in modules.items():
            if lo <= at < hi:
                hosts.setdefault(r, []).append(e)
                break
        else:
            die(
                f"{e['patch']}: the edit at {at} ({e['site']}) is not inside any "
                f"module's source — it cannot be code that runs"
            )

    # 1. Drop the bytecode cache for those modules, so the source is what runs.
    dropped = 0
    for r in hosts:
        off, ln = strp(data, r + bytecode)
        if ln:
            struct.pack_into("<II", data, r + bytecode, 0, 0)
            dropped += ln
    with open(path, "wb") as f:
        f.write(bytes(data))

    # 2. Prove it: the bytes are ours, and nothing shadows them any more.
    for r, es in hosts.items():
        name_off, name_len = strp(data, r)
        name = bytes(data[blob + name_off : blob + name_off + name_len]).decode()
        if strp(data, r + bytecode)[1] != 0:
            die(f"{name} still has bytecode; its patches would not run")
        for e in es:
            want = bytes.fromhex(e["bytes"])
            got = bytes(data[e["offset"] : e["offset"] + len(want)])
            if got != want:
                die(
                    f"{e['patch']}: the {e['site']} edit at {e['offset']} reads "
                    f"{got!r}, not the {want!r} it wrote — something rewrote the "
                    f"binary after the patch"
                )

    by_patch = collections.Counter(e["patch"] for e in edits)
    tally = ", ".join(f"{n} from {p}" for p, n in sorted(by_patch.items()))
    print(
        f"claude-bytecode-liveness: {len(edits)} edits live ({tally}); dropped "
        f"{dropped} bytes of bytecode across {len(hosts)} of {count} modules "
        f"(magic {magic.hex()})"
    )


if __name__ == "__main__":
    main()
