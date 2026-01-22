#!/bin/bash
# Raycast Config Import Helper
# Imports Raycast settings from stored config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../dotfiles/raycast"
INPUT_FILE="$CONFIG_DIR/raycast.rayconfig"
PASSWORD_FILE="$CONFIG_DIR/.raycast-password"

echo "Raycast Config Import"
echo "====================="
echo ""

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: No config found at $INPUT_FILE"
    echo "Run raycast-export.sh first to create one."
    exit 1
fi

if [[ -f "$PASSWORD_FILE" ]]; then
    PASSWORD=$(cat "$PASSWORD_FILE")
    echo "When Raycast asks for the password, use:"
    echo ""
    echo "    $PASSWORD"
    echo ""
else
    echo "Warning: No password file found at $PASSWORD_FILE"
    echo ""
fi

echo "Select this file when prompted:"
echo "    $INPUT_FILE"
echo ""
read -p "Press Enter to open Raycast import dialog..."

# Open Raycast import via deeplink
open "raycast://extensions/raycast/raycast/import-settings-data"
