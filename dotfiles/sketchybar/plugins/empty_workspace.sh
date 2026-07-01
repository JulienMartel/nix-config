#!/bin/bash
# empty_workspace.sh — when a ⌘Q empties the focused workspace, pull back to the
# most recent non-empty workspace ("gravity"), and keep the now-empty workspace
# out of AeroSpace's alt+tab (workspace-back-and-forth) target.
#
# Why this lives in a SketchyBar plugin and not the alt+tab keybinding:
#   alt+tab stays the native, instant `workspace-back-and-forth` — no wrapper,
#   no added latency. All the smarts run here, off macOS's front_app_switched
#   event, which fires on a ⌘Q (and on every workspace switch, which is how we
#   cheaply keep a focused-workspace history without touching aerospace.toml).
#
# Detecting a quit (vs. a plain app-switch or visiting an already-empty space):
#   each event records the frontmost app's PID; on the next event, if that PID
#   is now dead (kill -0 fails), the previous app was QUIT. Only then do we act.
#   Frontmost is read via lsappinfo (≈8ms) rather than osascript/System Events
#   (≈110ms) — this runs on every event, so the cheap path matters.
#
# Keeping the empty workspace out of alt+tab:
#   AeroSpace's back-and-forth toggles current <-> the ONE previously-focused
#   workspace, and there's no command to edit that pointer — but *visiting* a
#   workspace sets it. So rather than a single hop to the gravity target D
#   (which would leave the empty workspace as the back target), we hop
#   `workspace P; workspace D`, landing on D with the back target = P, the next
#   real workspace. Set SET_PREV=0 to use a single hop (no brief flicker through
#   P, but alt+tab may then return to the empty space).
#
# Wired as a non-drawing item subscribed to front_app_switched in sketchybarrc.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

AEROSPACE=/opt/homebrew/bin/aerospace

STATE=/tmp/sketchybar_empty_ws.state    # "<pid>|<name>" of last frontmost app
HIST=/tmp/sketchybar_empty_ws.hist      # focused-workspace history, most recent LAST
TOKEN=/tmp/sketchybar_empty_ws.token    # latest-event nonce; guards the fork
LOG=/tmp/sketchybar_empty_ws.log
SET_PREV=1                              # re-point back-and-forth via a P→D double hop
DEBUG=0

log() { [ "$DEBUG" = 1 ] && echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

# Frontmost app's pid + name, the cheap way.
asn=$(lsappinfo front 2>/dev/null)
cur_pid=$(lsappinfo info -only pid "$asn" 2>/dev/null);   cur_pid=${cur_pid#\"pid\"=}
cur_name=$(lsappinfo info -only name "$asn" 2>/dev/null); cur_name=${cur_name#\"LSDisplayName\"=}; cur_name=${cur_name#\"}; cur_name=${cur_name%\"}

# Read the previous frontmost, then record the current one for the next event.
prev=$(cat "$STATE" 2>/dev/null)
prev_pid=${prev%%|*}
prev_name=${prev#*|}
printf '%s|%s' "$cur_pid" "$cur_name" > "$STATE"

# Record focused-workspace history (dedup consecutive, keep last 12). This is
# how we later pick the gravity target D and the back target P.
focused=$($AEROSPACE list-workspaces --focused 2>/dev/null)
if [ -n "$focused" ] && [ "$focused" != "$(tail -1 "$HIST" 2>/dev/null)" ]; then
    echo "$focused" >> "$HIST"
    tail -12 "$HIST" > "$HIST.t" 2>/dev/null && mv "$HIST.t" "$HIST"
fi

log "event: prev=$prev cur=$cur_pid|$cur_name focused=$focused"

# Only a QUIT is interesting: previous frontmost recorded and now dead.
[ -n "$prev_pid" ] || { log "  no prev → skip"; exit 0; }
if kill -0 "$prev_pid" 2>/dev/null; then log "  prev alive → switch, skip"; exit 0; fi
case "$prev_name" in Pounce|pounce*) log "  prev is palette → skip"; exit 0 ;; esac
case "$cur_name"  in Pounce|pounce*) log "  cur is palette → skip";  exit 0 ;; esac

log "  QUIT detected (prev '$prev_name' dead) → fork"

nonce="$cur_pid.$prev_pid"
echo "$nonce" > "$TOKEN"
(
    # Act the instant the window is reaped — tight poll, not a fixed sleep, so
    # there's no noticeable sit on the empty workspace. The last fetched
    # non-empty set is reused below, so this costs no extra AeroSpace calls.
    reaped=0
    for _ in $(seq 1 20); do
        nonempty=$($AEROSPACE list-workspaces --monitor all --empty no 2>/dev/null)
        grep -qx "$focused" <<<"$nonempty" || { reaped=1; break; }
        sleep 0.01
    done
    [ "$reaped" = 1 ] || { log "  [fork] '$focused' still has windows → skip"; exit 0; }
    [ "$(cat "$TOKEN" 2>/dev/null)" = "$nonce" ] || { log "  [fork] superseded → skip"; exit 0; }
    now=$($AEROSPACE list-workspaces --focused 2>/dev/null)
    [ "$now" = "$focused" ] || { log "  [fork] moved off '$focused' → skip"; exit 0; }

    # Candidates = non-empty workspaces (excluding the one we're leaving),
    # ordered most-relevant first: recent history, then any other populated
    # workspace. D (gravity target) is the most recent — where you came from.
    # P (the new back-and-forth target) is the next one; falling back to a live
    # non-empty workspace when history has no second option is exactly what
    # keeps the just-emptied space out of alt+tab.
    ordered=()
    add() {
        local w=$1 c
        [ -z "$w" ] && return
        [ "$w" = "$focused" ] && return
        grep -qx "$w" <<<"$nonempty" || return
        for c in "${ordered[@]}"; do [ "$c" = "$w" ] && return; done
        ordered+=("$w")
    }
    while IFS= read -r ws; do add "$ws"; done < <(tail -r "$HIST" 2>/dev/null)
    for ws in $nonempty; do add "$ws"; done
    D=${ordered[0]}; P=${ordered[1]}

    if [ -z "$D" ]; then
        log "  [fork] no non-empty target → back-and-forth"
        exec "$AEROSPACE" workspace-back-and-forth
    fi

    if [ "$SET_PREV" = 1 ] && [ -n "$P" ]; then
        log "  [fork] gravity → $D (back target ← $P)"
        "$AEROSPACE" workspace "$P"; exec "$AEROSPACE" workspace "$D"
    else
        log "  [fork] gravity → $D"
        exec "$AEROSPACE" workspace "$D"
    fi
) &

exit 0
