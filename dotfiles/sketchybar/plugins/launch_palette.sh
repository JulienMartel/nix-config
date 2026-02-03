#!/bin/bash
# Launch choose-palette with proper GUI context
# Sketchybar click scripts run in a context that may not allow GUI apps to display
# This wrapper ensures the palette can open properly

# Include nix profile paths so choose-* commands are available
export PATH="/etc/profiles/per-user/julienmartel/bin:/run/current-system/sw/bin:$PATH"

# Run in background with nohup to detach from sketchybar's context
nohup /etc/profiles/per-user/julienmartel/bin/choose-palette >/dev/null 2>&1 &
