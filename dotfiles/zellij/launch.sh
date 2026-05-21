#!/bin/bash
# Ghostty → zellij launcher. Configured as ghostty's `command`.
# Debug log: /tmp/zellij-launch.log
set -u

# ghostty is launched by macOS launchd, which hands us a minimal PATH
# (/etc/paths contents only — no nix profile dirs). Prepend the nix paths
# so the nix-managed zellij always wins, even if a stray /usr/local/bin
# binary exists. Also set SHELL so zellij spawns the right shell.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
export SHELL="/bin/zsh"

LOG=/tmp/zellij-launch.log
SESSION="main"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

log "---- launch ----"

run_shell() {
    log "→ exec /bin/zsh -l"
    exec /bin/zsh -l
}

# Guard: already inside zellij, or user opted out.
if [ -n "${ZELLIJ:-}" ] || [ "${NO_ZELLIJ:-}" = "1" ]; then
    log "guard: nested or opted-out"
    run_shell
fi

# Quick-terminal detection (best-effort, ~100ms cost). Skip if you don't care.
title=$(/usr/bin/osascript -e 'tell application "System Events" to tell (first process whose frontmost is true) to get title of front window' 2>>"$LOG" || true)
if [[ "${title}" == *quick-terminal* ]]; then
    log "guard: quick-terminal"
    run_shell
fi

# Session policy: attach if "main" is alive, resurrect if exited, otherwise
# create fresh. Resurrection restores tabs/panes/cwds across mac restarts but
# uses the layout cached at session creation — to pick up custom.kdl edits,
# run `zellij delete-session --force main` once to force a clean rebuild.
if command -v zellij >/dev/null 2>&1; then
    log "zellij=$(command -v zellij) version=$(zellij --version 2>&1) PATH=$PATH"
    log "attach-or-create '${SESSION}'"
    zellij attach --create "${SESSION}" 2> >(tee -a "$LOG" >&2)
    log "zellij exited with code $?"
fi

# zellij has exited (detach, normal close, or error) — fall back to a plain
# shell so the ghostty window stays open. User can re-launch zellij or quit.
run_shell
