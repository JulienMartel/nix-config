#!/bin/bash
# Rebuild nix system configuration in a small centered ghostty window.
#
# Key constraints driving this script's shape:
#   - On macOS, `ghostty -e ...` from CLI is unsupported (per `ghostty --help`)
#     and `+new-window` is also unsupported, so we must use
#     `open -na Ghostty.app --args ...` to launch a fresh instance.
#   - That fresh instance reads `command = .../zellij/launch.sh` from the
#     user's ghostty config, which would otherwise spawn an extra zellij
#     window alongside the rebuild one. We override `command` on the CLI to
#     pin every window in this instance to the rebuild script.
#   - Window title `quick-terminal-rebuild` matches an existing
#     `on-window-detected` rule in dotfiles/aerospace.toml that floats the
#     window at creation time — no post-spawn `aerospace layout` dance.

WINDOW_TITLE="quick-terminal-rebuild"

# Find the frame of the screen the user is currently on, in Ghostty's
# top-origin coord system. We pick the screen by cursor location so a
# multi-display setup centers on whichever monitor the user is on right now.
# Use `frame` for containment (full bounds) but `visibleFrame` for centering
# (excludes menu bar / dock, so the window doesn't get clipped).
FRAME=$(osascript -l JavaScript -e '
  ObjC.import("AppKit");
  ObjC.import("CoreGraphics");
  var loc = $.CGEventGetLocation($.CGEventCreate($()));
  var screens = $.NSScreen.screens;
  if (screens.count === 0) {
    "0 0 1920 1080";
  } else {
    var primaryH = screens.objectAtIndex(0).frame.size.height;
    var pick = screens.objectAtIndex(0);
    for (var i = 0; i < screens.count; i++) {
      var s = screens.objectAtIndex(i);
      var fr = s.frame;
      var topY = primaryH - (fr.origin.y + fr.size.height);
      if (loc.x >= fr.origin.x && loc.x < fr.origin.x + fr.size.width &&
          loc.y >= topY      && loc.y < topY      + fr.size.height) {
        pick = s; break;
      }
    }
    var vf = pick.visibleFrame;
    var vTopY = primaryH - (vf.origin.y + vf.size.height);
    Math.round(vf.origin.x) + " " + Math.round(vTopY) + " " +
    Math.round(vf.size.width) + " " + Math.round(vf.size.height);
  }
' 2>/dev/null)
[ -z "$FRAME" ] && FRAME="0 0 1920 1080"
read -r SCREEN_X SCREEN_Y SCREEN_W SCREEN_H <<< "$FRAME"

COLS=80
ROWS=20
EST_W=750
EST_H=400
POS_X=$(( SCREEN_X + (SCREEN_W - EST_W) / 2 ))
POS_Y=$(( SCREEN_Y + (SCREEN_H - EST_H) / 2 ))

# Stable temp path so we don't need to thread a multiline script through
# `open --args`. Overwritten on every invocation.
REBUILD_TMP="/tmp/nix-rebuild-run.sh"
cat >"$REBUILD_TMP" <<'EOF'
#!/bin/bash
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
EOF
# Defensive: strip quarantine xattr so macOS Gatekeeper doesn't prompt.
xattr -d com.apple.quarantine "$REBUILD_TMP" 2>/dev/null || true

# Capture state BEFORE spawn:
#   - source workspace, so we can pin the window there even if aerospace's
#     catch-all `on-window-detected` rule grabs it to workspace T
#   - existing ghostty PIDs, so we can identify the *new* instance afterwards
#     and target it precisely (avoids hitting stale AX references in other
#     ghostty processes, which throw -1728 errAENoSuchObject)
SOURCE_WS=$(aerospace list-workspaces --focused 2>/dev/null)
BEFORE_PIDS=$(pgrep -x ghostty 2>/dev/null | sort -u)

open -na Ghostty.app --args \
  --title="$WINDOW_TITLE" \
  --window-width=$COLS \
  --window-height=$ROWS \
  --window-position-x=$POS_X \
  --window-position-y=$POS_Y \
  --command="bash $REBUILD_TMP"

# Step 1: find the PID of the new ghostty instance spawned by `open -na`.
# Polling every 20ms (vs 100ms) cuts detection time noticeably.
NEW_PID=""
for _ in $(seq 1 100); do
  AFTER_PIDS=$(pgrep -x ghostty 2>/dev/null | sort -u)
  NEW_PID=$(comm -13 <(printf '%s\n' "$BEFORE_PIDS") <(printf '%s\n' "$AFTER_PIDS") | head -1)
  [ -n "$NEW_PID" ] && break
  sleep 0.02
done

if [ -n "$NEW_PID" ]; then
  osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "System Events"
  tell (first process whose unix id is $NEW_PID)
    repeat 100 times
      try
        if (count windows) > 0 then
          set size of window 1 to {$EST_W, $EST_H}
          set position of window 1 to {$POS_X, $POS_Y}
          exit repeat
        end if
      end try
      delay 0.02
    end repeat
  end tell
end tell
APPLESCRIPT
fi

# Step 3: aerospace cleanup — move the window back to the source workspace
# (in case the broken catch-all `on-window-detected` rule already moved it
# to T) and force-float it. Runs after positioning so we don't fight our
# own AppleScript.
for _ in $(seq 1 30); do
  WID=$(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' 2>/dev/null \
        | awk -F'|' -v t="$WINDOW_TITLE" '$2 == "Ghostty" && $3 == t {print $1; exit}')
  if [ -n "$WID" ]; then
    [ -n "$SOURCE_WS" ] && aerospace move-node-to-workspace --window-id "$WID" "$SOURCE_WS" 2>/dev/null
    aerospace layout --window-id "$WID" floating 2>/dev/null
    break
  fi
  sleep 0.03
done
