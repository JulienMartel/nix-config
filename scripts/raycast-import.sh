#!/bin/bash
# Raycast Config Import Helper
# Imports Raycast settings from the stored JSON config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../dotfiles/raycast"
INPUT_FILE="$CONFIG_DIR/raycast-config.json"
OUTPUT_FILE="$CONFIG_DIR/raycast-import.rayconfig"

echo "Raycast Config Import"
echo "====================="
echo ""

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: No config found at $INPUT_FILE"
    echo "Run raycast-export.sh first to create one."
    exit 1
fi

echo "Converting JSON to .rayconfig format..."

# Compress the JSON back to rayconfig format
gzip --keep --stdout "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Created: $OUTPUT_FILE"
echo ""
echo "Opening Raycast import dialog..."
echo "Select the file: $OUTPUT_FILE"
echo ""

# Open Raycast import via deeplink
open "raycast://extensions/raycast/raycast/import-settings-data"

echo "After importing, you can delete the .rayconfig file:"
echo "  rm \"$OUTPUT_FILE\""
