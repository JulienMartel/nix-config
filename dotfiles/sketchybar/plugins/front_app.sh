#!/bin/bash

# Get the front app name
FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')

# While AeroSpace's resize mode is armed (see resize_mode.sh), keep the resize
# glyph appended — focusing the other window repaints this label, which would
# otherwise drop it. fa-arrows-h (U+F07E); keep in sync with resize_mode.sh.
if [ -f /tmp/sketchybar_resize_state ]; then
    GLYPH=$(printf '\xEF\x81\xBE')
    /opt/homebrew/bin/sketchybar --set "$NAME" label="$FRONT_APP $GLYPH"
else
    /opt/homebrew/bin/sketchybar --set "$NAME" label="$FRONT_APP"
fi
