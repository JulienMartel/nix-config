#!/bin/bash

TARGET="$HOME/.config/nix"

# Try to open with Cursor (Bundle ID from AeroSpace config)
if open -b com.todesktop.230313mzl4w4u92 "$TARGET"; then
    exit 0
fi

# Try VS Code
if open -a "Visual Studio Code" "$TARGET"; then
    exit 0
fi

# Fallback to default open (Finder)
open "$TARGET"
