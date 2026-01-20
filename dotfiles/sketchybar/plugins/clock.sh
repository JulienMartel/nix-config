#!/bin/zsh

# Get current date and time
DATE=$(date '+%a %b %d')
TIME=$(date '+%I:%M %p')

# Nerd Font calendar icon (nf-fa-calendar)
ICON=$(printf "\uf073")

# Update the bar item
/opt/homebrew/bin/sketchybar --set $NAME \
    icon="$ICON" \
    label="$DATE  $TIME"
