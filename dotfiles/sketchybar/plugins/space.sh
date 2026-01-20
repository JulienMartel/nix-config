#!/bin/bash

# Catppuccin Mocha Colors
MAUVE=0xffcba6f7
SURFACE0=0xff313244
BASE=0xff1e1e2e
TEXT=0xffcdd6f4

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
