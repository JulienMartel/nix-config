#!/bin/bash

# Colors
MAUVE=0xff8839ef
SURFACE0=0xffccd0da
BASE=0xffeff1f5

if [ "$SELECTED" = "true" ]; then
    sketchybar --set $NAME \
        background.color=$MAUVE \
        icon.color=$BASE \
        label.color=$BASE
else
    sketchybar --set $NAME \
        background.color=$SURFACE0 \
        icon.color=0xff4c4f69 \
        label.color=0xff4c4f69
fi
