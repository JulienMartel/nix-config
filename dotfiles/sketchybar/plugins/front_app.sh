#!/bin/bash

# Get the front app name
FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')

# Update the bar item
sketchybar --set $NAME label="$FRONT_APP"
