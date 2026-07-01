#!/bin/bash
# Super-Shift-t "New tab" flow: launched as a zellij floating pane. Browse in yazi
# (starts at $HOME; l/Right to enter dirs, h/Left up), then Enter on the folder
# you want spawns a new zellij tab cwd'd there and auto-named after the repo
# (git-root basename, or the dir basename if it isn't a repo). Press q or Esc to
# cancel — the pane just closes and no tab is created.
#
# The Enter=pick / q=cancel behaviour comes from the dedicated picker keymap in
# ~/.config/yazi-picker (see dotfiles/yazi/picker/): Enter runs `enter` + `quit`
# so yazi writes the chosen dir to --cwd-file, while q/Esc run `quit
# --no-cwd-file` so nothing is written and the tab-spawn block below is skipped.
set -u
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
export YAZI_CONFIG_HOME="$HOME/.config/yazi-picker"

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
