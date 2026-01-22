#!/bin/bash
# Raycast Config Export Helper
# Stores Raycast export for version control

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../dotfiles/raycast"
OUTPUT_FILE="$CONFIG_DIR/raycast.rayconfig"
PASSWORD_FILE="$CONFIG_DIR/.raycast-password"
PASSWORD="raycast2026"

echo "Raycast Config Export"
echo "====================="
echo ""
echo "When Raycast asks for a password, use:"
echo ""
echo "    $PASSWORD"
echo ""
echo "(This password is saved in $PASSWORD_FILE)"
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

mkdir -p "$CONFIG_DIR"

# Save the password
echo "$PASSWORD" > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Copy the rayconfig file
cp "$RAYCONFIG_PATH" "$OUTPUT_FILE"

echo ""
echo "Success! Config saved to: $OUTPUT_FILE"
echo ""
echo "Don't forget to commit the changes:"
echo "  cd ~/.config/nix && git add -A && git commit -m 'Update Raycast config'"
