#!/bin/bash

exec 2>>/tmp/sketchybar_space.log
set -x

# Catppuccin Mocha Colors
MAUVE=0xffcba6f7
SURFACE0=0xff313244
BASE=0xff1e1e2e
TEXT=0xffcdd6f4

# Get current workspace from AeroSpace
CURRENT_WORKSPACE=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
AEROSPACE_EXIT_CODE=$?

# Get all non-empty workspaces (workspaces with windows)
WORKSPACES_WITH_WINDOWS=$(/opt/homebrew/bin/aerospace list-workspaces --monitor all --empty no)

# Log for debugging
echo "$(date) - Item: $NAME, ID: ${NAME#space.}, Current: $CURRENT_WORKSPACE (Exit: $AEROSPACE_EXIT_CODE), Windows: $WORKSPACES_WITH_WINDOWS" >> /tmp/sketchybar_space.log

# Extract workspace ID from item name (space.1 -> 1, space.C -> C)
WORKSPACE_ID="${NAME#space.}"

# Check if this workspace is the focused workspace
if [ "$WORKSPACE_ID" = "$CURRENT_WORKSPACE" ]; then
    echo "  -> Active" >> /tmp/sketchybar_space.log
    # Active workspace - highlight it
    /opt/homebrew/bin/sketchybar --set $NAME \
        background.color=$MAUVE \
        icon.color=$BASE \
        label.color=$BASE \
        drawing=on
# Check if this workspace has windows
elif echo "$WORKSPACES_WITH_WINDOWS" | grep -q "^${WORKSPACE_ID}$"; then
    echo "  -> Inactive with windows" >> /tmp/sketchybar_space.log
    # Inactive workspace with windows
    /opt/homebrew/bin/sketchybar --set $NAME \
        background.color=$SURFACE0 \
        icon.color=$TEXT \
        label.color=$TEXT \
        drawing=on
else
    echo "  -> Empty" >> /tmp/sketchybar_space.log
    # Workspace is empty and not focused - hide it
    /opt/homebrew/bin/sketchybar --set $NAME drawing=off
fi
