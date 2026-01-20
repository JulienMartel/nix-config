#!/bin/bash

# Get CPU usage percentage
CPU_USAGE=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s}')

# Update the bar item
sketchybar --set $NAME label="${CPU_USAGE}%"
