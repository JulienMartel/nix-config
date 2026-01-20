#!/bin/bash

# Define specific title
WINDOW_TITLE="quick-terminal-rebuild"
SCRIPT_PATH="$HOME/.config/nix/dotfiles/sketchybar/plugins/nix_rebuild.sh"

echo "--- Launching Rebuild (Flags Method) ---" > /tmp/rebuild_debug.log

# Get screen dimensions
# Using system_profiler can be more reliable for physical resolution, 
# but osascript gives us the "points" dimension which is what window placement usually uses.
DIMS=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' | tr -d ',')
SCREEN_W=$(echo $DIMS | awk '{print $3}')
SCREEN_H=$(echo $DIMS | awk '{print $4}')

echo "Detected Screen: ${SCREEN_W}x${SCREEN_H}" >> /tmp/rebuild_debug.log

# Window Config (Reduced size for safety)
# 80 cols * ~9px = 720px
# 15 rows * ~22px = 330px
COLS=80
ROWS=15
EST_W=750
EST_H=350

# Calculate Center Position
# Shift left by ~125px and up by ~50px based on user feedback
POS_X=$(( (($SCREEN_W - $EST_W) / 2) - 125 ))
POS_Y=$(( (($SCREEN_H - $EST_H) / 2) - 50 ))

# Ensure non-negative
if [ $POS_X -lt 0 ]; then POS_X=0; fi
if [ $POS_Y -lt 0 ]; then POS_Y=0; fi

echo "Calculated Pos: ${POS_X},${POS_Y}" >> /tmp/rebuild_debug.log

# Launch Ghostty using explicit position flags
# We REMOVE --window-save-state=never just in case it interferes with explicit flags,
# although logic suggests flags should override.
open -n -a Ghostty --args \
  --title="$WINDOW_TITLE" \
  --window-height=$ROWS \
  --window-width=$COLS \
  --window-position-x=$POS_X \
  --window-position-y=$POS_Y \
  -e bash -c "$SCRIPT_PATH"

sketchybar --set apple.logo popup.drawing=off
