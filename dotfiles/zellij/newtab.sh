#!/bin/bash
# Super-t "New tab" flow: launched as a zellij floating pane. Pick a directory in
# yazi (starts at $HOME; use `z` to zoxide-jump), quit (q), and this spawns a new
# zellij tab cwd'd there and auto-named after the repo (git-root basename, or the
# dir basename if it isn't a repo). Replaces zellij's blank NewTab.
#
# Cancelling yazi without moving leaves you at $HOME, which basename()s to your
# username — harmless; the tab just won't be repo-named until you cd.
set -u
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"

tmp="$(mktemp -t yazi-cwd.XXXXXX)"
yazi --cwd-file="$tmp" "$HOME"
cwd="$(cat -- "$tmp" 2>/dev/null)"
rm -f -- "$tmp"

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    name="$(basename "$cwd")"
    root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
    [ -n "$root" ] && name="$(basename "$root")"
    zellij action new-tab --cwd "$cwd" --name "$name"
fi

# Selection made or cancelled — either way close this floating picker pane.
exit 0
