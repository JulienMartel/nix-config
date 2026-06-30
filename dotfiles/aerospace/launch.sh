#!/bin/bash
# Launch (or focus) an app, optionally on a specific workspace.
#
#   launch.sh "AppName"          # open/focus in the CURRENT workspace
#   launch.sh "AppName" S        # switch to workspace S first, then open/focus
#
# Switching to the assigned workspace BEFORE opening avoids the jank where the
# app appears on the current workspace and then on-window-detected yanks it to
# its assigned one. When the target is already focused, on-window-detected is a
# no-op and there's nothing visible to move.

app="$1"
ws="$2"

# Undim the bar immediately. Safe no-op when invoked outside launch mode (e.g.
# the hyper-chord fallback bindings) — disarm bails when nothing is armed.
/Users/julienmartel/.config/sketchybar/plugins/launch_mode.sh off 2>/dev/null

[ -n "$ws" ] && aerospace workspace "$ws"
open -a "$app"
