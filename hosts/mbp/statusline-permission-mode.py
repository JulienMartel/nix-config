#!/usr/bin/env python3
"""Add `permission_mode` to the JSON Claude Code pipes into the custom statusline.

Claude Code re-runs the statusline command on every permission-mode flip already
— the mode is a dependency of the effect that fires it, so shift+tab schedules a
re-render within its 300ms debounce. What it never does is *tell* the script what
the mode now is: the statusline payload has cwd/model/cost/context_window/vim/pr/
worktree and no permission mode, and no hook event fires on a flip either. So the
rice statusline had to read the mode out of the transcript instead, where Claude
Code stamps it only at TURN BOUNDARIES — leaving the mode chip frozen on "the
mode as of your last submitted turn" while you cycle. Not a refresh problem; a
payload problem, and the payload is one identifier away from being right.

The builder function already receives the live mode as its first destructured
parameter (`function <fn>({permissionMode:<ident>, …})`) and uses it only to
resolve the model id. This patch emits it as well, so the statusline reads
`.permission_mode` from stdin and the chip tracks shift+tab live.

Byte-length-preserving, like declutter-claude-footer.py and for the same reason
(bun's module graph indexes the embedded JS source by offset). And inert for the
same reason too: since 2.1.259 the bundle carries a JSC bytecode cache compiled
from that source and bun runs the cache, so this edit only reaches the payload
once claude-bytecode-liveness.py drops the bytecode for the module it lands in.
That script is also the guard — the edit below goes into the shared manifest and
it proves, out of the finished binary, that the patched source is what runs.

The bytes come from the version banner inlined at the same site: the whole
`{ISSUES_EXPLAINER:…,VERSION:"x.y.z",…}.VERSION` object literal there just to
read one field off it, so replacing that expression with the version string it
evaluates to frees ~360 bytes — far more than `permission_mode:<ident>,` needs.
The slack is padded back with spaces, which an object literal doesn't mind.

Anchors pin structure, not minified identifier names (which change every
release): `version:{ISSUES_EXPLAINER` … `.VERSION,output_style:{name:` is a run
of payload KEYS, all of them part of the documented statusline schema, and
`({permissionMode:` is the builder's own parameter name. Both are stable across
releases in a way that `yRS`/`e`/`y` are not. If a claude-code update reshapes
the payload nothing matches and this script exits non-zero, failing the nix
build loudly rather than silently shipping a statusline whose mode chip has
quietly gone back to lying. To re-derive: search the binary for
'exceeds_200k_tokens:' and read outward.

The consumer is haus's modules/core/statusline.sh, which prefers
`.permission_mode` and falls back to the transcript tail — so a stock,
unpatched claude-code still renders a (turn-boundary) mode chip, and this patch
is a pure upgrade rather than a dependency.

Usage: statusline-permission-mode.py <path-to-claude-binary> <edits-manifest>
"""

import json
import re
import sys

path, manifest = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = bytearray(f.read())

edits = []

ident = rb"[A-Za-z_$][\w$]{0,5}"

# The payload site: `version:{ISSUES_EXPLAINER:…,VERSION:"x.y.z",…}.VERSION,
# output_style:{name:<var>},cost:` — an inlined banner object read for one field,
# immediately followed by two more payload keys that pin it as the statusline
# object and not some other use of the banner (there are ~15 of those).
site = re.compile(
    rb'version:\{ISSUES_EXPLAINER:.{0,900}?VERSION:"([\d.]+)".{0,400}?\}\.VERSION,'
    rb"output_style:\{name:(%s)\},cost:" % ident,
    re.S,
)

matches = list(site.finditer(bytes(data)))
patched = 0
for m in matches:
    version, style_var = m.group(1), m.group(2)
    # The live mode is the builder's first destructured parameter. Look back for
    # the enclosing function head rather than assuming a name for it.
    head = re.search(
        rb"\(\{permissionMode:(%s)[,:}]" % ident,
        bytes(data[max(0, m.start() - 4000) : m.start()]),
    )
    if head is None:
        continue
    mode_var = head.group(1)
    new = (
        b'version:"%s",permission_mode:%s,output_style:{name:%s},cost:'
        % (version, mode_var, style_var)
    )
    pad = len(m.group()) - len(new)
    if pad < 0:
        continue
    # Pad between properties — whitespace inside an object literal is free.
    new = new.replace(b",output_style:", b"," + b" " * pad + b"output_style:", 1)
    assert len(new) == len(m.group())
    data[m.start() : m.end()] = new
    edits.append(
        {
            "patch": "statusline-permission-mode",
            "site": "statusline payload",
            "offset": m.start(),
            "bytes": new.hex(),
        }
    )
    patched += 1

# Not a count guard: patching zero sites means the anchors stopped matching and
# the mode chip is back to reading a stale transcript. Whether a patched site
# then reaches the payload is claude-bytecode-liveness.py's question.
if not patched:
    sys.exit(
        f"statusline-permission-mode: patched no statusline payload builder "
        f"(found {len(matches)} candidate sites) — the claude-code update "
        f"changed the statusline payload; re-derive the anchors (see script "
        f"header) or drop the patch."
    )

with open(path, "wb") as f:
    f.write(bytes(data))
with open(manifest, "a") as f:
    for edit in edits:
        f.write(json.dumps(edit) + "\n")
print(
    f"statusline-permission-mode: added permission_mode to {patched} payload "
    f"builder in {path}"
)
