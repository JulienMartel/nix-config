#!/bin/bash

# Recent Screenshots: open the two-pane screenshot picker (same layout as the
# clipboard history). Enter copies the highlighted shot to the clipboard as both
# an image (paste into Slack/Notion) and a file reference (⌘V in Finder). The
# list is newest-first, so the top row is the latest screenshot.
#
# Re-invokes `choose` in screenshots mode; the daemon swaps it into the live
# palette window (this command is registered submenu=true), so there's no
# close→reopen flash between the palette and the picker.
exec choose --screenshots
