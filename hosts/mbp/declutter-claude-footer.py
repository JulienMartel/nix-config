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

  2. The empty-state placeholder, `<var>=<fn>()?<jsx>(<Text>,{children:" "})
     :null` (the placeholder-line reservation; an assignment as of CC 2.1.220,
     formerly a `return`), gets its condition overwritten in place with a
     same-length always-false expression, so the idle blank line renders as
     null.

  3. The right-hand CHIP STRIP is a *sibling* row, not part of either box
     above, so collapsing them never touched it: a column stack pinned with
     `marginLeft:"auto"` whose contents are the hipaa banner, the cloud /
     remote-control chip ("/rc"), the IDE-selection chip, "Debug", the PR
     status chip and the mode labels ("focus", "memory paused"), joined with
     " · ". It stayed invisible until CC 2.1.220 shipped `/rc` and the focus
     ("briefTranscript") label, which are on permanently here — so the row
     came back as a second line under our statusline in every pane. Its
     component already returns null when it has no chips; we flip that
     emptiness test to always-true (`.length===0` -> `.length> -1`, same
     length), so the strip renders null unconditionally and any chip a future
     release adds there can't bring the line back. Our own statusline already
     carries the PR link and everything else we care about.

We patch the JS source that bun embeds as plain text inside the compiled binary
(verified empirically that the embedded source — not a bytecode cache — is what
executes). All edits are byte-length-preserving because the bun trailer indexes
the embedded source by offset; changing its length corrupts the binary.

Anchors pin code STRUCTURE, not minified identifier names (which change every
release): the object-literal prop keys `height`/`overflow`/`children` and the
`{children:" "}` placeholder are Ink API names and stay stable; the `children:[`
(array) vs `children:<jsx>(` (single child) distinction is what separates our
two content rows from the unrelated spinner box, and the leading `=`
(assignment) separates the two footer placeholders from the custom-statusline
container's own fallback, whose identical `...jsx(<Text>,{children:" "}):null`
tail is instead preceded by `:` (a ternary else-branch). The chip strip is
pinned by its own two halves at once — the early `return null` on an empty
chip ARRAY and, further down, that same array being spread into the Box as
`children:<same var>.flatMap(` — a pairing nothing else in the binary has
(the bare `.length===0){return null}` appears 25 times). If a claude-code
update reshapes any of it a match count moves off its expected value and this
script exits non-zero — failing the nix build loudly instead of silently
bringing the row back. To re-derive: search the binary for
'overflow:"hidden",children:[', 'children:" "}):null' and '.flatMap('.

Usage: declutter-claude-footer.py <path-to-claude-binary>
"""

import re
import sys

EXPECTED_ROWS = 2  # the two variants of the footer status row
EXPECTED_RESERVATIONS = 2  # their two idle placeholder-line early returns
EXPECTED_STRIPS = 1  # the right-hand chip strip ("/rc \xb7 focus")

path = sys.argv[1]
with open(path, "rb") as f:
    data = bytearray(f.read())

ident = rb"[A-Za-z_$][\w$]{0,5}"

# 1. The non-empty footer row: a Box with a children ARRAY (jsxs). Flip its
#    fixed height 1 -> 0 so the row collapses to zero rows. `children:[`
#    (not `children:<jsx>(`) is what excludes the single-child spinner box,
#    which is the only other `height:1,overflow:"hidden"` render nearby.
row = re.compile(rb'\{height:1,overflow:"hidden",children:\[')
rows = 0
for m in row.finditer(bytes(data)):
    h = data.index(b"height:1", m.start(), m.end())
    data[h : h + len(b"height:1")] = b"height:0"
    rows += 1

# 2. The idle placeholder reservation: `<var>=<fn>()?<jsx>.jsx(<Text>,
#    {children:" "}):null` (an assignment; CC ≤2.1.195 wrote it as a `return`).
#    Overwrite the condition with a same-length always-false expression so the
#    blank line renders as null. The leading `=` (assignment) distinguishes
#    these two footer placeholders from the custom-statusline container's own
#    `:<fn>()?<jsx>.jsx(<Text>,{children:" "}):null` fallback, whose identical
#    jsx tail is instead preceded by `:` (a ternary else-branch).
reservation = re.compile(
    rb"=((?:%s)\(\))\?(?:%s)\.jsx\((?:%s),\{children:\" \"\}\):null"
    % (ident, ident, ident)
)
reservations = 0
for m in reservation.finditer(bytes(data)):
    cond_start, cond_end = m.span(1)
    data[cond_start:cond_end] = b"!1".rjust(cond_end - cond_start)  # same length
    reservations += 1

# 3. The right-hand chip strip: `if(<chips>.length===0){return null}` … later
#    `children:<chips>.flatMap(`. Same array variable on both ends is what
#    identifies THIS component; the early return alone is a common shape.
#    Flip the emptiness test to an always-true comparison, same byte length,
#    so the strip is always null.
strip = re.compile(
    rb"if\((%s)\.length===0\)\{return null\}.{0,400}?children:\1\.flatMap\("
    % ident,
    re.DOTALL,
)
strips = 0
for m in strip.finditer(bytes(data)):
    t = data.index(b"===0", m.start(), m.start() + 40)
    data[t : t + 4] = b"> -1"  # same length
    strips += 1

if (
    rows != EXPECTED_ROWS
    or reservations != EXPECTED_RESERVATIONS
    or strips != EXPECTED_STRIPS
):
    sys.exit(
        f"declutter-claude-footer: expected {EXPECTED_ROWS} footer rows + "
        f"{EXPECTED_RESERVATIONS} placeholder reservations + "
        f"{EXPECTED_STRIPS} chip strip, found {rows} + {reservations} + "
        f"{strips} — the claude-code update changed the footer code; "
        f"re-derive the anchors (see script header) or drop the patch."
    )

with open(path, "wb") as f:
    f.write(bytes(data))
print(
    f"declutter-claude-footer: collapsed {rows} footer rows + "
    f"{reservations} placeholder reservations + {strips} chip strip in {path}"
)
