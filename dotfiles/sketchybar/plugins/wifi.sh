#!/bin/bash

# Catppuccin Mocha Colors
RED=0xfff38ba8
TEAL=0xff94e2d5

# Get WiFi status
WIFI_STATUS=$(networksetup -getairportnetwork en0 | awk -F': ' '{print $2}')

if [ "$WIFI_STATUS" = "You are not associated with an AirPort network." ] || [ -z "$WIFI_STATUS" ]; then
    sketchybar --set $NAME \
        icon=󰖪 \
        label="Disconnected" \
        icon.color=$RED
else
    sketchybar --set $NAME \
        icon=󰖩 \
        label="$WIFI_STATUS" \
        icon.color=$TEAL
fi
