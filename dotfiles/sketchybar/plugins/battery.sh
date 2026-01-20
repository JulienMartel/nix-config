#!/bin/bash

# Catppuccin Mocha Colors
GREEN=0xffa6e3a1
YELLOW=0xfff9e2af
RED=0xfff38ba8

# Get battery info
BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(echo "$BATTERY_INFO" | grep 'AC Power')

# Determine icon and color
if [ -n "$CHARGING" ]; then
    ICON="󰂄"
    COLOR=$GREEN
else
    if [ "$PERCENTAGE" -gt 80 ]; then
        ICON="󰁹"
        COLOR=$GREEN
    elif [ "$PERCENTAGE" -gt 60 ]; then
        ICON="󰂀"
        COLOR=$GREEN
    elif [ "$PERCENTAGE" -gt 40 ]; then
        ICON="󰁿"
        COLOR=$YELLOW
    elif [ "$PERCENTAGE" -gt 20 ]; then
        ICON="󰁼"
        COLOR=$YELLOW
    else
        ICON="󰁺"
        COLOR=$RED
    fi
fi

# Update the bar item
sketchybar --set $NAME \
    icon="$ICON" \
    icon.color=$COLOR \
    label="${PERCENTAGE}%"
