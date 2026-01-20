#!/bin/bash

# Catppuccin Mocha Colors
MAUVE=0xffcba6f7
SURFACE0=0xff313244
BASE=0xff1e1e2e
TEXT=0xffcdd6f4

# Get current workspace from AeroSpace
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)

# Get all non-empty workspaces (workspaces with windows)
WORKSPACES_WITH_WINDOWS=$(aerospace list-workspaces --monitor all --empty no)

# Extract workspace ID from item name (space.1 -> 1, space.C -> C)
WORKSPACE_ID="${NAME#space.}"

# Check if this workspace has windows or is the focused workspace
if echo "$WORKSPACES_WITH_WINDOWS" | grep -q "^${WORKSPACE_ID}$" || [ "$WORKSPACE_ID" = "$CURRENT_WORKSPACE" ]; then
    # Workspace has windows or is focused - show it
    if [ "$WORKSPACE_ID" = "$CURRENT_WORKSPACE" ]; then
        # Active workspace - highlight it
        sketchybar --set $NAME \
            background.color=$MAUVE \
            icon.color=$BASE \
            label.color=$BASE \
            drawing=on
    else
        # Inactive workspace with windows
        sketchybar --set $NAME \
            background.color=$SURFACE0 \
            icon.color=$TEXT \
            label.color=$TEXT \
            drawing=on
    fi
else
    # Workspace is empty and not focused - hide it
    sketchybar --set $NAME drawing=off
fi
