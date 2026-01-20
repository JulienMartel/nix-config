#!/bin/bash

# Get volume level
VOLUME=$(osascript -e 'output volume of (get volume settings)')
MUTED=$(osascript -e 'output muted of (get volume settings)')

# Determine icon
if [ "$MUTED" = "true" ]; then
    ICON="󰖁"
    LABEL="Muted"
elif [ "$VOLUME" -gt 66 ]; then
    ICON="󰕾"
    LABEL="${VOLUME}%"
elif [ "$VOLUME" -gt 33 ]; then
    ICON="󰖀"
    LABEL="${VOLUME}%"
elif [ "$VOLUME" -gt 0 ]; then
    ICON="󰕿"
    LABEL="${VOLUME}%"
else
    ICON="󰖁"
    LABEL="0%"
fi

# Update the bar item
sketchybar --set $NAME \
    icon="$ICON" \
    label="$LABEL"
