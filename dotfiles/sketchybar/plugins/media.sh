#!/bin/bash

STATE="$(echo "$INFO" | jq -r '.state')"

if [ "$STATE" = "playing" ]; then
    MEDIA="$(echo "$INFO" | jq -r '.title + " - " + .artist')"
    /opt/homebrew/bin/sketchybar --set $NAME \
        label="$MEDIA" \
        drawing=on
else
    /opt/homebrew/bin/sketchybar --set $NAME drawing=off
fi
