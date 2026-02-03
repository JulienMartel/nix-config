#!/bin/bash
# Open nix config directory in preferred editor

NIX_CONFIG_DIR="$HOME/.config/nix"

# Try Cursor first, then VS Code, then Finder
if open -b "com.todesktop.230313mzl4w4u92" "$NIX_CONFIG_DIR" 2>/dev/null; then
    exit 0
elif command -v code &>/dev/null; then
    code "$NIX_CONFIG_DIR"
else
    open "$NIX_CONFIG_DIR"
fi
