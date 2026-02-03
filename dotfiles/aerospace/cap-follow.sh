#!/bin/bash
# Move cap.so windows to the focused workspace

FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)
CAP_APP_ID="so.cap.desktop"

# Get all cap.so window IDs and move them to current workspace
WINDOW_IDS=$(aerospace list-windows --monitor all --app-id "$CAP_APP_ID" 2>/dev/null | cut -d'|' -f1 | tr -d ' ')

for WINDOW_ID in $WINDOW_IDS; do
    if [ -n "$WINDOW_ID" ]; then
        aerospace move-node-to-workspace "$FOCUSED_WORKSPACE" --window-id "$WINDOW_ID" 2>/dev/null
    fi
done
