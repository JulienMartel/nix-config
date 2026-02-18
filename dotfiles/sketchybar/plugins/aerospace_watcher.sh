#!/bin/bash

# Batch-update all workspace indicators in one pass
# Much more efficient than triggering 13 individual space.sh runs

MAUVE=0xffcba6f7
SURFACE0=0xff313244
BASE=0xff1e1e2e
TEXT=0xffcdd6f4

CURRENT=$(/opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null)
WITH_WINDOWS=$(/opt/homebrew/bin/aerospace list-workspaces --monitor all --empty no 2>/dev/null)

ARGS=()
for workspace in 1 2 3 4 C T N S B G L F M; do
    if [ "$workspace" = "$CURRENT" ]; then
        ARGS+=(--set space.$workspace background.color=$MAUVE icon.color=$BASE label.color=$BASE drawing=on)
    elif echo "$WITH_WINDOWS" | grep -q "^${workspace}$"; then
        ARGS+=(--set space.$workspace background.color=$SURFACE0 icon.color=$TEXT label.color=$TEXT drawing=on)
    else
        ARGS+=(--set space.$workspace drawing=off)
    fi
done

/opt/homebrew/bin/sketchybar "${ARGS[@]}"
