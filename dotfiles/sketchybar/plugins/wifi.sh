#!/bin/bash

# Get WiFi status
WIFI_STATUS=$(networksetup -getairportnetwork en0 | awk -F': ' '{print $2}')

if [ "$WIFI_STATUS" = "You are not associated with an AirPort network." ] || [ -z "$WIFI_STATUS" ]; then
    sketchybar --set $NAME \
        icon=󰖪 \
        label="Disconnected" \
        icon.color=0xffd20f39
else
    sketchybar --set $NAME \
        icon=󰖩 \
        label="$WIFI_STATUS" \
        icon.color=0xff179299
fi
