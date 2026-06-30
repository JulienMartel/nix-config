#!/bin/bash
# launch_mode.sh on|off
#
# Spotlights AeroSpace's `launch` leader-mode by dimming the WHOLE bar: every
# on-screen pill fades to a low-contrast grey while the Apple logo — the
# launcher itself — glows Catppuccin mauve. Tapping caps (F18) arms it; esc or
# any launch action disarms it. There is no dedicated "LAUNCH" pill; the modal
# state IS the dimmed bar.
#
# Restore is exact: `on` snapshots each visible pill's current colors and `off`
# replays them, so dynamic pills (focused workspace, battery level, wifi state,
# Elgato/Harvest status) return to their real colors without re-running their
# scripts — no weather/API refetch on every leader tap.
#
# While armed, each pill's script is frozen (updates=off) so a periodic refresh
# (harvest 3s, wifi/clock 10s, battery 30s, …) can't repaint over the dim. The
# original `updates` value is snapshotted and restored on disarm.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

SNAP="/tmp/sketchybar_launch_dim.json"

# Catppuccin Mocha
MAUVE=0xffcba6f7
BASE=0xff1e1e2e
MANTLE=0xff181825
OVERLAY0=0xff6c7086

# Dim target: pills sink toward the bar; icons/labels drop to a muted grey.
DIM_BG=$MANTLE
DIM_FG=$OVERLAY0

arm() {
    # Snapshot once. A second `on` (double cap-tap) must not capture the
    # already-dimmed state, so only snapshot when none is in flight.
    if [ ! -f "$SNAP" ]; then
        for item in $(sketchybar --query bar | jq -r '.items[]'); do
            sketchybar --query "$item"
        done | jq -s '
            [ .[]
              | select(any(.bounding_rects[]?; .origin[0] >= 0))   # on-screen pills only
              | { name,
                  bg:      (.geometry.background.color // "0x00000000"),
                  icon:    (.icon.color  // "0xffffffff"),
                  label:   (.label.color // "0xffffffff"),
                  updates: (.scripting.updates // "when_shown") } ]' > "$SNAP"
    fi

    # Fade every snapshotted pill and freeze its script, then light the launcher
    # mauve. updates=off stops periodic/event repaints from undoing the dim.
    local args
    args=$(jq -r ".[].name | \"--set \(.) background.color=$DIM_BG icon.color=$DIM_FG label.color=$DIM_FG updates=off\"" "$SNAP" | tr '\n' ' ')
    eval "sketchybar $args --set apple.logo background.color=$MAUVE icon.color=$BASE"
}

disarm() {
    [ -f "$SNAP" ] || return 0
    local args
    args=$(jq -r '.[] | "--set \(.name) background.color=\(.bg) icon.color=\(.icon) label.color=\(.label) updates=\(.updates)"' "$SNAP" | tr '\n' ' ')
    eval "sketchybar $args"
    rm -f "$SNAP"
}

case "$1" in
    on)  arm ;;
    off) disarm ;;
    *)   echo "usage: $0 on|off" >&2; exit 1 ;;
esac
