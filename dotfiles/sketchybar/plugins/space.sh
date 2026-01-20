#!/bin/bash

# Colors
MAUVE=0xff8839ef
SURFACE0=0xffccd0da
BASE=0xffeff1f5
TEXT=0xff4c4f69

# Get current workspace from AeroSpace
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)

# Extract workspace number from item name (space.1 -> 1)
WORKSPACE_NUM="${NAME#space.}"

if [ "$WORKSPACE_NUM" = "$CURRENT_WORKSPACE" ]; then
    sketchybar --set $NAME \
        background.color=$MAUVE \
        icon.color=$BASE \
        label.color=$BASE
else
    sketchybar --set $NAME \
        background.color=$SURFACE0 \
        icon.color=$TEXT \
        label.color=$TEXT
fi
