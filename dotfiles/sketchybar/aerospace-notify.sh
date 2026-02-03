#!/bin/bash
/opt/homebrew/bin/sketchybar --trigger aerospace_workspace_change

# Move cap.so windows to follow workspace changes
~/.config/aerospace/cap-follow.sh &
