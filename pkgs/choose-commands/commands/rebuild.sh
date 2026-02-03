#!/bin/bash
# Rebuild nix system configuration
# Opens in a terminal window so user can see progress

# Get screen dimensions for window positioning
screen_width=$(system_profiler SPDisplaysDataType | grep Resolution | head -1 | awk '{print $2}')
screen_height=$(system_profiler SPDisplaysDataType | grep Resolution | head -1 | awk '{print $4}')

# Default to reasonable values if detection fails
screen_width=${screen_width:-1920}
screen_height=${screen_height:-1080}

# Calculate window size and position (centered, slightly up and left)
win_width=750
win_height=400
win_x=$(( (screen_width - win_width) / 2 - 125 ))
win_y=$(( (screen_height - win_height) / 2 - 50 ))

# Ensure positive coordinates
win_x=$(( win_x > 0 ? win_x : 100 ))
win_y=$(( win_y > 0 ? win_y : 100 ))

# The actual rebuild script to run in terminal
REBUILD_SCRIPT='
# Ensure nix is in PATH
export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

cd ~/.config/nix || exit 1

echo "Building nix configuration..."
echo ""

if nix build .#darwinConfigurations.mbp.system; then
    echo ""
    echo "Build successful. Switching..."
    echo ""
    if sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp; then
        echo ""
        echo "✓ System rebuild complete!"
    else
        echo ""
        echo "✗ Switch failed"
    fi
else
    echo ""
    echo "✗ Build failed"
fi

echo ""
echo "Press any key to close..."
read -n 1 -s
'

# Check for available terminal emulators
if command -v ghostty &>/dev/null; then
    ghostty \
        --title="Nix Rebuild" \
        --window-width=80 \
        --window-height=20 \
        --window-position-x="$win_x" \
        --window-position-y="$win_y" \
        -e bash -c "$REBUILD_SCRIPT" &

    # Give it a moment to open, then set floating via aerospace
    sleep 0.3
    aerospace list-windows --all | grep "Nix Rebuild" | awk '{print $1}' | xargs -I {} aerospace layout --window-id {} floating 2>/dev/null
elif command -v alacritty &>/dev/null; then
    alacritty \
        --title "Nix Rebuild" \
        --option "window.dimensions.columns=80" \
        --option "window.dimensions.lines=20" \
        -e bash -c "$REBUILD_SCRIPT" &
else
    # Fallback to Terminal.app
    osascript <<EOF
tell application "Terminal"
    activate
    do script "cd ~/.config/nix && nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp; echo ''; echo 'Press any key to close...'; read -n 1 -s; exit"
end tell
EOF
fi
