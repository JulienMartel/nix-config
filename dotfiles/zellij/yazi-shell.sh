#!/bin/bash
# Super-Shift-y "Jump" flow: launched as a zellij floating pane. Browse in yazi,
# navigate to wherever you want, quit (q) — and this pane becomes a login shell
# sitting in that directory. A disposable scratch terminal that lands where you
# were looking, floating over your tiled claude panes without disturbing them.
#
# Inherits the focused pane's cwd from zellij, so yazi opens rooted in the repo
# of whatever pane you triggered it from.
set -u
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"

tmp="$(mktemp -t yazi-cwd.XXXXXX)"
yazi --cwd-file="$tmp"
cwd="$(cat -- "$tmp" 2>/dev/null)"
rm -f -- "$tmp"

[ -n "$cwd" ] && [ -d "$cwd" ] && cd -- "$cwd"

exec /bin/zsh -l
