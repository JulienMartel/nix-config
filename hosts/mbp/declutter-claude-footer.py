#!/usr/bin/env python3
"""Collapse Claude Code's bottom "footer status row" out of the TUI.

That row is the strip Claude Code renders just below the prompt box. It shows,
in one line: the permission-mode badge ("⏵⏵ auto mode on"), a tasks indicator,
Claude Code's own link chips (e.g. "PR #35"), and transient hints ("? for
shortcuts", "⎋ for agents", "esc to interrupt / return to team lead", "hold X
to speak"). Crucially, even when it has *nothing* to show it doesn't collapse —
it renders a one-space placeholder line to reserve the row so the layout
doesn't jump. There is no setting to hide any of this (checked v2.1.195: the
statusline docs say the custom statusline renders ABOVE the built-in footer and
cannot replace it).

We run our own statusline right above this row (branch, PR link, cost, context
%), so the whole built-in row is redundant — and its idle placeholder is a
permanent blank line. So instead of silencing just the mode badge, we collapse
the entire row. Two things do that, in each of the row's two code variants (a
dense feature-flagged one and the normal one), so four patches total:

  1. The non-empty render, `return li.jsxs(<Box>,{height:1,overflow:"hidden",
     children:[...]})`, gets its `height:1` flipped to `height:0`. With
     overflow hidden a zero-height box occupies zero terminal rows, so mode +
     tasks + link chips + hints all vanish visually.

  2. The empty-state placeholder, `return <fn>()?<jsx>(<Text>,{children:" "})
     :null` (the placeholder-line reservation; a `return` again as of CC
     2.1.259, an assignment in 2.1.220–2.1.227), gets its condition overwritten
     in place with a same-length always-false expression, so the idle blank
     line renders as null.

  3. The right-hand CHIP STRIP is a *sibling* row, not part of either box
     above, so collapsing them never touched it: a column stack pinned with
     `marginLeft:"auto"` whose contents are the hipaa banner, the cloud /
     remote-control chip ("/rc"), the IDE-selection chip, "Debug", the PR
     status chip and the mode labels ("focus", "memory paused"), joined with
     " · ". It stayed invisible until CC 2.1.220 shipped `/rc` and the focus
     ("briefTranscript") label, which are on permanently here — so the row
     came back as a second line under our statusline in every pane. Its
     component already returns null when it has nothing to show; we overwrite
     that emptiness test with a same-length always-true `!0`, so the strip
     renders null unconditionally and any chip a future release adds there
     can't bring the line back. Our own statusline already carries the PR link
     and everything else we care about.

We patch the JS source that bun embeds as plain text inside the compiled
binary. All edits are byte-length-preserving because bun's module graph indexes
the embedded source by offset; changing its length corrupts the binary. Since
2.1.259 the bundle ALSO carries a JSC bytecode cache compiled from that source,
and bun runs the cache — so every edit here is inert until
claude-bytecode-liveness.py drops the bytecode for the modules we touched. That
script is also what fails the build now: each edit below is written to the shared
manifest, and it re-reads them out of the finished binary and proves each one
lands in code that actually executes. A count of matches could never do that —
this patch applied cleanly and changed nothing on screen for all of 2.1.259.

Anchors pin code STRUCTURE, not minified identifier names (which change every
release): the object-literal prop keys `height`/`overflow`/`children` and the
`{children:" "}` placeholder are Ink API names and stay stable; the `children:[`
(array) vs `children:<jsx>(` (single child) distinction is what separates our
two content rows from the unrelated spinner box, and the leading `return ` (or
`=`, the 2.1.220–2.1.227 shape) separates the two footer placeholders from the
custom-statusline container's own fallback, whose identical
`...(<Text>,{children:" "}):null` tail is instead preceded by `:` (a ternary
else-branch). The chip strip is pinned by its own two halves at once — the
early `return null` on an empty chip ARRAY and, further down, that same array
being handed to the Box as `children:<same var>` — a pairing nothing else in
the binary has (the bare `.length===0){return null}` appears 26 times). If a
claude-code update reshapes any of them this script finds none of that kind and
exits non-zero, failing the nix build loudly instead of silently bringing the
row back. To re-derive: search the binary for 'overflow:"hidden",children:[',
'children:" "}):null' and '.length===0&&'.

Usage: declutter-claude-footer.py <path-to-claude-binary> <edits-manifest>
"""

import json
import re
import sys

path, manifest = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = bytearray(f.read())

edits = []


def write(at, new, site):
    """Overwrite in place and tell the liveness check where to look."""
    data[at : at + len(new)] = new
    edits.append(
        {
            "patch": "declutter-claude-footer",
            "site": site,
            "offset": at,
            "bytes": new.hex(),
        }
    )


ident = rb"[A-Za-z_$][\w$]{0,5}"

# 1. The non-empty footer row: a Box with a children ARRAY (jsxs). Flip its
#    fixed height 1 -> 0 so the row collapses to zero rows. `children:[`
#    (not `children:<jsx>(`) is what excludes the single-child spinner box,
#    which is the only other `height:1,overflow:"hidden"` render nearby.
row = re.compile(rb'\{height:1,overflow:"hidden",children:\[')
rows = 0
for m in row.finditer(bytes(data)):
    h = data.index(b"height:1", m.start(), m.end())
    write(h, b"height:0", "footer row height")
    rows += 1

# 2. The idle placeholder reservation: `return <fn>()?<jsx>(<Text>,
#    {children:" "}):null` (a `return` again as of CC 2.1.259; 2.1.220–2.1.227
#    wrote it as an assignment, hence the `=` alternative). Overwrite the
#    condition with a same-length always-false expression so the blank line
#    renders as null. The `return ` / `=` prefix distinguishes these two footer
#    placeholders from the custom-statusline container's own
#    `:<fn>()?<jsx>(<Text>,{children:" "}):null` fallback, whose identical jsx
#    tail is instead preceded by `:` (a ternary else-branch). The jsx call is
#    bare (`<fn>(`) since 2.1.259 and namespaced (`<ns>.jsx(`) before it.
reservation = re.compile(
    rb"(?:=|return )((?:%s)\(\))\?(?:%s\.jsx|%s)\((?:%s),\{children:\" \"\}\):null"
    % (ident, ident, ident, ident)
)
reservations = 0
for m in reservation.finditer(bytes(data)):
    cond_start, cond_end = m.span(1)
    same_length = b"!1".rjust(cond_end - cond_start)
    write(cond_start, same_length, "placeholder reservation")
    reservations += 1

# 3. The right-hand chip strip: `if(<chips>.length===0&&<modes>===null){return
#    null}` … later `children:<chips>`. Same array variable on both ends is
#    what identifies THIS component; the early return alone is a common shape.
#    (2.1.259 added the `&&<modes>===null` half — the mode labels became a
#    sibling of the chip array — and stopped spreading the array with
#    `.flatMap(`, hence both being optional/loose here.) Overwrite the whole
#    emptiness test with a same-length always-true `!0` so the strip is always
#    null, whatever a future release adds to either half.
strip = re.compile(
    rb"if\(((%s)\.length===0(?:&&(?:%s)===null)?)\)\{return null\}"
    rb".{0,400}?children:\2[.}]" % (ident, ident),
    re.DOTALL,
)
strips = 0
for m in strip.finditer(bytes(data)):
    cond_start, cond_end = m.span(1)
    same_length = b"!0".rjust(cond_end - cond_start)
    write(cond_start, same_length, "chip strip")
    strips += 1

# The old guard demanded exactly 2 + 2 + 1, which passed all through 2.1.259
# while the row it hides was on screen the whole time — matching is not the
# thing worth asserting. What is left here is the floor: finding NONE of a kind
# means that kind's anchor stopped matching. Whether the edits reach the screen
# is claude-bytecode-liveness.py's question now, and it is the one that failed.
if not (rows and reservations and strips):
    sys.exit(
        f"declutter-claude-footer: found {rows} footer rows + {reservations} "
        f"placeholder reservations + {strips} chip strips, and needs at least "
        f"one of each — the claude-code update changed the footer code; "
        f"re-derive the anchors (see script header) or drop the patch."
    )

with open(path, "wb") as f:
    f.write(bytes(data))
with open(manifest, "a") as f:
    for edit in edits:
        f.write(json.dumps(edit) + "\n")
print(
    f"declutter-claude-footer: collapsed {rows} footer rows + "
    f"{reservations} placeholder reservations + {strips} chip strip in {path}"
)
