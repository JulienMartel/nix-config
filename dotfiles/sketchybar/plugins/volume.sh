#!/bin/bash

# Get volume level
VOLUME=$(osascript -e 'output volume of (get volume settings)')
MUTED=$(osascript -e 'output muted of (get volume settings)')

# Determine icon
if [ "$MUTED" = "true" ]; then
    ICON="婢"
    VOLUME="Muted"
elif [ "$VOLUME" -gt 66 ]; then
    ICON=""
elif [ "$VOLUME" -gt 33 ]; then
    ICON="奔"
elif [ "$VOLUME" -gt 0 ]; then
    ICON=""
else
    ICON="婢"
fi

# Update the bar item
sketchybar --set $NAME \
    icon="$ICON" \
    label="${VOLUME}%"
