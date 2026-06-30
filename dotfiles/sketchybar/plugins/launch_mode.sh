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
# While armed, EVERY item's script is frozen (updates=off) so neither a pill's
# own periodic refresh (harvest 3s, wifi/clock 10s, battery 30s, …) nor a hidden
# batch-updater (aerospace_watcher polls every 2s and repaints the workspaces
# via external --set, which updates=off on the space.* items can't block) can
# repaint over the dim. Each item's original `updates` value is snapshotted and
# restored on disarm.

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
        # Capture ALL items (a hidden updater like aerospace_watcher must be
        # frozen too), flagging which are currently on-screen so only those get
        # dimmed/restored.
        for item in $(sketchybar --query bar | jq -r '.items[]'); do
            sketchybar --query "$item"
        done | jq -s '
            [ .[]
              | { name,
                  vis:     (any(.bounding_rects[]?; .origin[0] >= 0)),
                  bg:      (.geometry.background.color // "0x00000000"),
                  icon:    (.icon.color  // "0xffffffff"),
                  label:   (.label.color // "0xffffffff"),
                  updates: (.scripting.updates // "when_shown") } ]' > "$SNAP"
    fi

    # Freeze every item's script, dim the on-screen pills, then light the
    # launcher mauve.
    local freeze dim
    freeze=$(jq -r '.[] | "--set \(.name) updates=off"' "$SNAP" | tr '\n' ' ')
    dim=$(jq -r ".[] | select(.vis) | \"--set \(.name) background.color=$DIM_BG icon.color=$DIM_FG label.color=$DIM_FG\"" "$SNAP" | tr '\n' ' ')
    eval "sketchybar $freeze $dim --set apple.logo background.color=$MAUVE icon.color=$BASE"
}

disarm() {
    [ -f "$SNAP" ] || return 0
    # Restore the visible pills' colors, then thaw every script back to its
    # original updates value (a thawed updater repaints to live state, which
    # matches the snapshot we just replayed).
    local restore thaw
    restore=$(jq -r '.[] | select(.vis) | "--set \(.name) background.color=\(.bg) icon.color=\(.icon) label.color=\(.label)"' "$SNAP" | tr '\n' ' ')
    thaw=$(jq -r '.[] | "--set \(.name) updates=\(.updates)"' "$SNAP" | tr '\n' ' ')
    eval "sketchybar $restore $thaw"
    rm -f "$SNAP"
}

case "$1" in
    on)  arm ;;
    off) disarm ;;
    *)   echo "usage: $0 on|off" >&2; exit 1 ;;
esac
