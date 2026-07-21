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

  2. The empty-state early return, `return <fn>()?<jsx>(<Text>,{children:" "})
     :null` (the placeholder-line reservation), gets its condition overwritten
     in place with a same-length always-false expression, so the idle blank
     line renders as null.

We patch the JS source that bun embeds as plain text inside the compiled binary
(verified empirically that the embedded source — not a bytecode cache — is what
executes). All edits are byte-length-preserving because the bun trailer indexes
the embedded source by offset; changing its length corrupts the binary.

Anchors pin code STRUCTURE, not minified identifier names (which change every
release): the object-literal prop keys `height`/`overflow`/`children` and the
`{children:" "}` placeholder are Ink API names and stay stable; the `children:[`
(array) vs `children:<jsx>(` (single child) distinction is what separates our
two content rows from the unrelated spinner box, and the leading `return `
separates the two footer placeholders from the custom-statusline container's
own `:<fn>()?" ":null` fallback. If a claude-code update reshapes the footer
either match count moves off 2 and this script exits non-zero — failing the nix
build loudly instead of silently bringing the row back. To re-derive: search
the binary for 'overflow:"hidden",children:[' and 'children:" "}):null'.

Usage: declutter-claude-footer.py <path-to-claude-binary>
"""

import re
import sys

EXPECTED_ROWS = 2  # the two variants of the footer status row
EXPECTED_RESERVATIONS = 2  # their two idle placeholder-line early returns

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

# 2. The idle placeholder reservation: `return <fn>()?<jsx>(<Text>,
#    {children:" "}):null`. Overwrite the condition with a same-length
#    always-false expression so the blank line renders as null. The leading
#    `return ` distinguishes these from the custom-statusline container's own
#    `:<fn>()?" ":null` fallback (an else-branch, not a statement).
reservation = re.compile(
    rb"return ((?:%s)\(\))\?(?:%s)\.jsx\((?:%s),\{children:\" \"\}\):null"
    % (ident, ident, ident)
)
reservations = 0
for m in reservation.finditer(bytes(data)):
    cond_start, cond_end = m.span(1)
    data[cond_start:cond_end] = b"!1".rjust(cond_end - cond_start)  # same length
    reservations += 1

if rows != EXPECTED_ROWS or reservations != EXPECTED_RESERVATIONS:
    sys.exit(
        f"declutter-claude-footer: expected {EXPECTED_ROWS} footer rows + "
        f"{EXPECTED_RESERVATIONS} placeholder reservations, found {rows} + "
        f"{reservations} — the claude-code update changed the footer code; "
        f"re-derive the anchors (see script header) or drop the patch."
    )

with open(path, "wb") as f:
    f.write(bytes(data))
print(
    f"declutter-claude-footer: collapsed {rows} footer rows + "
    f"{reservations} placeholder reservations in {path}"
)
