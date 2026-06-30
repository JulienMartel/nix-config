#!/bin/bash
# resize_mode.sh on|off
#
# Indicator for AeroSpace's `resize` mode (entered via the launch leader's -/=).
# Recolors the front-app pill catppuccin yellow and appends a horizontal-resize
# glyph to the end of the app name. `off` restores the normal lavender pill and
# the bare app name. Mirrors the front_app pill defined in sketchybarrc.
#
# A state file (STATE) records that the mode is armed: front_app.sh reads it so
# that focusing the other window in the workspace (which fires front_app_switched
# and repaints the label) keeps the glyph instead of dropping it.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

STATE="/tmp/sketchybar_resize_state"   # present == armed

# Catppuccin Mocha
YELLOW=0xfff9e2af
LAVENDER=0xffb4befe
BASE=0xff1e1e2e

# fa-arrows-h (U+F07E) as raw UTF-8 bytes — /bin/bash is 3.2, whose printf has
# no \u/\U; \xHH works. Keep in sync with front_app.sh.
GLYPH=$(printf '\xEF\x81\xBE')

front_app() {
    osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'
}

case "$1" in
    on)
        : > "$STATE"
        sketchybar --set front_app background.color=$YELLOW label.color=$BASE \
                                    label="$(front_app) $GLYPH"
        ;;
    off)
        rm -f "$STATE"
        sketchybar --set front_app background.color=$LAVENDER label.color=$BASE \
                                    label="$(front_app)"
        ;;
    *)
        echo "usage: $0 on|off" >&2; exit 1 ;;
esac
