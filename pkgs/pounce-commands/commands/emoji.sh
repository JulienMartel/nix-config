#!/bin/bash

# Emoji Picker: open the emoji grid with fuzzy name/keyword search. Enter copies
# the highlighted emoji to the clipboard and records frecency so frequently used
# glyphs float to the top.
#
# Re-invokes `pounce` in emoji mode; the daemon swaps it into the live palette
# window (this command is registered submenu=true), so there's no close→reopen
# flash between the palette and the picker.
exec pounce --emoji
