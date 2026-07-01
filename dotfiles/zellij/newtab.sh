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

    # zellij's `new-tab --cwd` is silently ignored when a custom default_layout
    # with a default_tab_template is active (v0.44) — the tab spawns in $HOME
    # regardless. Work around it by cloning the active layout and injecting a
    # `cwd` onto its content tab (tab-level cwd IS honored; root-level is not),
    # then opening the tab from that layout. Reusing custom.kdl verbatim keeps
    # the tab-bar/status-bar and the spiral/columns/grid swap layouts intact.
    layout_src="$HOME/.config/zellij/layouts/custom.kdl"
    gen=""
    if [ -f "$layout_src" ]; then
        # KDL-escape the path (backslash then double-quote) for the cwd string.
        esc="${cwd//\\/\\\\}"; esc="${esc//\"/\\\"}"
        # Reused, overwritten each run — no per-invocation temp file to race the
        # zellij server on cleanup, and it never accumulates.
        gen="${TMPDIR:-/tmp}/zellij-newtab-$USER.kdl"
        awk -v cwd="$esc" '
            /^    tab \{$/ && !done { print "    tab cwd=\"" cwd "\" {"; done=1; next }
            { print }
        ' "$layout_src" > "$gen"
        grep -q '^    tab cwd=' "$gen" || gen=""
    fi

    if [ -n "$gen" ]; then
        zellij action new-tab --layout "$gen" --name "$name"
    else
        # Fallback (layout missing/reformatted): at least name the tab; cwd may
        # land in $HOME until the layout can be cloned again.
        zellij action new-tab --cwd "$cwd" --name "$name"
    fi
fi

# Selection made or cancelled — either way close this floating picker pane.
exit 0
