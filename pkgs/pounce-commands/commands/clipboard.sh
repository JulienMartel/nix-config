#!/bin/bash

# Clipboard History: open the two-pane clipboard picker. Enter restores the
# highlighted entry to the clipboard — and, when clipboard.autoPaste is enabled
# and the daemon holds Accessibility, pastes it straight into the previously
# focused app (synthesize ⌘V), Raycast-style.
#
# Re-invokes `pounce` in clipboard mode; the daemon swaps it into the live
# palette window (this command is registered submenu=true), so there's no
# close→reopen flash between the palette and the picker.
exec pounce --clipboard
