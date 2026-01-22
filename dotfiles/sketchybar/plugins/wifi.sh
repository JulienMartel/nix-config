#!/bin/bash

# Catppuccin Mocha Colors
RED=0xfff38ba8
TEAL=0xff94e2d5

# Get Wi-Fi status using ipconfig (more reliable than networksetup on newer macOS)
INFO=$(ipconfig getsummary en0)
LINK_STATUS=$(echo "$INFO" | grep "LinkStatusActive" | awk -F': ' '{print $2}')
SSID=$(echo "$INFO" | grep "SSID" | awk -F': ' '{print $2}')

if [ "$LINK_STATUS" = "TRUE" ]; then
    LABEL="$SSID"
    # Fallback if SSID is redacted or missing
    if [[ "$SSID" == *"<redacted>"* ]] || [ -z "$SSID" ]; then
        LABEL="Connected"
    fi
    
    /opt/homebrew/bin/sketchybar --set $NAME \
        icon=󰖩 \
        label.drawing=off \
        icon.color=$TEAL
else
    /opt/homebrew/bin/sketchybar --set $NAME \
        icon=󰖪 \
        label.drawing=off \
        icon.color=$RED
fi
