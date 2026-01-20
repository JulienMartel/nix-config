#!/bin/bash
# Raycast Config Export Helper
# Exports Raycast settings to JSON for version control

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../dotfiles/raycast"
OUTPUT_FILE="$CONFIG_DIR/raycast-config.json"

echo "Raycast Config Export"
echo "====================="
echo ""
echo "This will open Raycast's export dialog."
echo ""
echo "IMPORTANT: When exporting, do NOT set a password."
echo "           (Leave password fields empty)"
echo ""
echo "Save the .rayconfig file somewhere accessible (e.g., Downloads)."
echo ""
read -p "Press Enter to open Raycast export dialog..."

# Open Raycast export via deeplink
open "raycast://extensions/raycast/raycast/export-settings-data"

echo ""
read -p "Enter the path to your exported .rayconfig file: " RAYCONFIG_PATH

# Expand tilde if present
RAYCONFIG_PATH="${RAYCONFIG_PATH/#\~/$HOME}"

if [[ ! -f "$RAYCONFIG_PATH" ]]; then
    echo "Error: File not found: $RAYCONFIG_PATH"
    exit 1
fi

# Decompress the rayconfig (it's gzip compressed when no password is set)
echo ""
echo "Decompressing to JSON..."

mkdir -p "$CONFIG_DIR"

# gzip with --suffix strips .rayconfig and produces the decompressed file
TEMP_DIR=$(mktemp -d)
TEMP_FILE="$TEMP_DIR/raycast.rayconfig"
cp "$RAYCONFIG_PATH" "$TEMP_FILE"

if gzip --decompress --suffix .rayconfig "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_DIR/raycast" "$OUTPUT_FILE"
    rm -rf "$TEMP_DIR"
    echo "Success! Config saved to: $OUTPUT_FILE"
    echo ""
    echo "Don't forget to commit the changes:"
    echo "  cd ~/.config/nix && git add -A && git commit -m 'Update Raycast config'"
else
    rm -rf "$TEMP_DIR"
    echo ""
    echo "Error: Could not decompress file."
    echo "This usually means the export was password-protected."
    echo "Please re-export WITHOUT a password."
    exit 1
fi
