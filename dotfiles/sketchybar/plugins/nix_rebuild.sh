#!/bin/bash

# Set window title explicitly using escape sequence
echo -ne "\033]0;quick-terminal-rebuild\007"

# Ensure nix is in PATH
export PATH=$PATH:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin

# Navigate to the nix config directory
cd ~/.config/nix || exit 1

echo "Starting Nix Rebuild..."
echo "Command: nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp"
echo ""

# Run the build command
nix build .#darwinConfigurations.mbp.system

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build successful. Switching configuration (sudo required)..."
    sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
else
    echo "Build failed!"
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

echo ""
echo "Process completed."
read -n 1 -s -r -p "Press any key to close..."
