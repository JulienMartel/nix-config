#!/bin/bash

# Get current date and time
DATE=$(date '+%a %b %d')
TIME=$(date '+%I:%M %p')

# Update the bar item
sketchybar --set $NAME \
    icon="" \
    label="$DATE  $TIME"
