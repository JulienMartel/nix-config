#!/usr/bin/env python3
"""Strip Claude Code's permission-mode footer line ("⏵⏵ auto mode on (shift+tab
to cycle)") from the TUI.

There is no setting for this (checked v2.1.195: the statusline docs explicitly
say the custom statusline renders ABOVE the built-in footer and cannot replace
it), so we patch the JS source that bun embeds as plain text inside the
compiled binary. Verified empirically that the embedded source — not a
bytecode cache — is what executes.

The footer component builds the line as
    <name> = <cond> ? <jsx>.jsxs(..., [ symbol, label.toLowerCase(), " on",
                                        "(<chord> to cycle)" ], "mode") : null
in two variants (a dense one behind a feature flag, and the normal one). Both
are matched by one regex anchored on the render call plus the '.toLowerCase()'
+ '" on"' payload nearby, and the condition is overwritten in place with a
same-length always-false expression, so the whole line renders as null and its
row collapses.

Identifiers are minifier-generated and change every release, so the regex only
pins structure, not names. If a claude-code update changes the code shape the
match count moves off 2 and this script exits non-zero — failing the nix build
loudly instead of silently bringing the footer back. To re-derive the
patterns, search the binary for '.toLowerCase()," on"'.

Usage: declutter-claude-footer.py <path-to-claude-binary>
"""

import re
import sys

EXPECTED_SITES = 2

path = sys.argv[1]
with open(path, "rb") as f:
    data = bytearray(f.read())

ident = rb"[A-Za-z_$][\w$]{0,5}"
# <name>=<cond>?<factory>.jsxs(  — cond is 1-4 &&-chained (possibly !!-negated)
# minified identifiers, e.g. `ge=Z&&X&&pe?li.jsxs(` or `qt=tt&&Z?li.jsxs(`
site = re.compile(
    rb"(?:%s)=((?:!!)?(?:%s)(?:&&(?:!!)?(?:%s)){1,3})\?(?:%s)\.jsxs\("
    % (ident, ident, ident, ident)
)
# ...whose rendered children contain the mode label + " on" suffix
payload = re.compile(rb'\.toLowerCase\(\)," on"')

patched = 0
for m in site.finditer(bytes(data)):
    if not payload.search(data[m.end() : m.end() + 400]):
        continue
    cond_start, cond_end = m.span(1)
    false_expr = b"!1".rjust(cond_end - cond_start)  # same length, always false
    data[cond_start:cond_end] = false_expr
    patched += 1

if patched != EXPECTED_SITES:
    sys.exit(
        f"declutter-claude-footer: expected {EXPECTED_SITES} footer render "
        f"sites, found {patched} — the claude-code update changed the footer "
        f"code; re-derive the patterns (see script header) or drop the patch."
    )

with open(path, "wb") as f:
    f.write(bytes(data))
print(f"declutter-claude-footer: patched {patched} render sites in {path}")
