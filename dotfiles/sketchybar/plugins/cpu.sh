#!/bin/zsh

# Get CPU usage percentage
CPU_USAGE=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s}')

# Nerd Font CPU icon (nf-md-cpu_64_bit)
ICON=$(printf "\uf4bc")

# Update the bar item
/opt/homebrew/bin/sketchybar --set $NAME \
    icon="$ICON" \
    label="${CPU_USAGE}%"
