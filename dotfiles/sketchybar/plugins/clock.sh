#!/bin/bash

# Get current date and time
TIME=$(date '+%a %b %d  %I:%M %p')

# Update the bar item
sketchybar --set $NAME label="$TIME"
