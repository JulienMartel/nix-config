#!/bin/bash
# pounce: name = Add To-do
# pounce: description = A to-do into the tracker — later by default, ⇥ for now or someday
# pounce: icon = checkmark.circle
# pounce: submenu = true
#
# One box. Type the to-do, then:
#
#   ↵    add it, unfiled — the root of tracker/, the inbox
#   ⇥    the chip: later (the default) · now · someday. A `--dial`, so it is a
#        value the commit carries rather than a second step; pounce reopens it
#        on whatever you committed last
#   ⌘↵   pick a project first — a grid of folders — then add it there. On an
#        EMPTY box it only picks the project and hands the box back, so
#        "where" can come before "what"
#   ⌃↵   add, then open the note in Obsidian. The one Return that takes the
#        screen, because you asked to see the note
#   ⌥↵   your drafts (Use / Delete / Clear all), and back into the box
#   ⇧↵   a newline: line one is the title, the rest is the note's body
#
# Dismissal keeps the text (`--draft`), exactly as Spawn Agent does: the
# palette closes on a stray click, and a half-typed to-do is gone otherwise.
#
# ⌘↵ and ⌥↵ are chained — each is answered by another `pounce` within
# milliseconds (the project grid, the drafts list), and an unchained step
# fades out while the next box presents INTO that fade, the race
# spawn-agent.sh measured. ↵ and ⌃↵ are not: nothing of the palette's follows
# them, and a held skeleton with nothing to fill it lingers eight seconds.
#
# `submenu = true` is what makes the box appear at all: the palette commits a
# submenu command with a loading disposition and holds the window until this
# script's own `pounce` presents into it, instead of closing on the pick.
#
# Modelled on haus's modules/launcher/commands/spawn-agent.sh. It lives in
# hosts/mbp/pounce/commands, an out-of-store symlink into
# ~/.config/pounce/commands (shell.nix), so an edit is live with no rebuild.
set -u

# A launchd GUI agent's PATH is bare; resolve our tools (tracker, pounce, jq,
# open) explicitly — the same prelude spawn-agent.sh uses. tracker sits in the
# per-user profile, haus-notify in the system one.
export PATH="/etc/profiles/per-user/${USER:-$(id -un)}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

PROMPT="Add To-do"
ICON="checkmark.circle"
# One drafts store for the command: you often start typing before deciding
# which project it belongs to.
DRAFT_KEY="todo-add"
# An obsidian:// URL names the vault by NAME. TRACKER_VAULT, when set, is the
# path the CLI reads, and the vault's name is its basename.
VAULT="$(basename "${TRACKER_VAULT:-notes}")"
# Where tracker's stderr and write reports go. A launchd GUI agent has no
# stderr a person will read, and the notices below are one line each.
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/tracker/pounce.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || LOG=/dev/null

# ── menu_commit / menu_field ──────────────────────────────────────────────
# Copied verbatim from haus's modules/launcher/commands/lib/menu-commit.sh —
# the one parse of a pounce menu answer. Inline because this script is not in
# haus's command directory: the lib sits beside spawn-agent.sh in a store path
# that moves on every rebuild, and a `.` of it here would break on the first.
#
#   MENU_ACTION  enter / cmd / opt / ctrl, read from the FIRST line only
#   MENU_ROW     everything after the first tab — the raw row, or typed text,
#                newlines and tabs of a ⇧↵ answer untouched
#   menu_field <row> <n>   field n of the row's first line; EMPTY past the
#                end, which is what tells a typed answer from a picked row
# shellcheck disable=SC2034
menu_commit() {
  local answer="${1-}"
  case "${answer%%$'\n'*}" in
    *$'\t'*)
      MENU_ACTION="${answer%%$'\t'*}"
      MENU_ROW="${answer#*$'\t'}"
      ;;
    *)
      MENU_ACTION=""
      MENU_ROW="$answer"
      ;;
  esac
}
menu_field() { printf '%s\t' "${1%%$'\n'*}" | cut -f"$2"; }

# A `--dial` step's commit grows one MIDDLE field —
# "<action>\t<when=value>\t<text>" — so this step strips TWO fields where a
# plain one strips one. dial_when answers "was there a dial field at all", and
# answers no whenever it cannot be sure, because a false yes eats the first
# line of somebody's to-do: a daemon older than the flag answers in the
# two-field shape (caught by the field count), a to-do that begins "when=" is
# ordinary text (caught by the count too), and a value we never offered is
# not ours to act on (the membership test).
dial_when() {
  local line value
  line="${1%%$'\n'*}"
  [ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" -ge 3 ] || return 1
  value="$(printf '%s' "$line" | cut -f2)"
  case "$value" in when=*) value="${value#when=}" ;; *) return 1 ;; esac
  case "$value" in now | later | someday) printf '%s' "$value" ;; *) return 1 ;; esac
}
# The other half: everything after the SECOND tab of the first line, newlines
# in the text itself untouched.
dial_payload() { printf '%s' "$1" | /usr/bin/sed $'1s/^[^\t]*\t[^\t]*\t//'; }

# A one-row pounce that says what happened — the palette's own toast.
notice() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-exclamationmark.triangle}" |
    pounce -p "$PROMPT" -i "$ICON" >/dev/null
}

# RFC 3986 percent-encoding, one path segment at a time so the slashes stay:
# for the `file=` half of an obsidian:// URL and for a file:// URL alike.
uri_path() { printf '%s' "$1" | jq -Rr 'split("/") | map(@uri) | join("/")'; }
# …and back, for a file:// line tracker may already have encoded.
pct_decode() { printf '%b' "${1//%/\\x}"; }

for tool in tracker jq; do
  command -v "$tool" >/dev/null 2>&1 && continue
  notice "$tool is unavailable" "Rebuild haus, then try again"
  exit 1
done

# ── the box ───────────────────────────────────────────────────────────────
# $1: text the box opens with (a draft coming back, or the text you had
# before a trip out to the project grid). The project, once picked, rides
# the placeholder — the one place a free-text step can show state.
ask() {
  printf '' | pounce --dial "when=later|now|someday" \
    --draft "$DRAFT_KEY" \
    --actions "Add|cmd:Pick a project|ctrl:Add and open|opt:Drafts" \
    --chain cmd,opt \
    --query "$1" \
    -p "What needs doing${project:+ in $project}?" -i "$ICON"
}

# ── which project ─────────────────────────────────────────────────────────
# Cards, not rows: a project is a thing — a folder with a count — and
# `--grid` is pounce's shape for exactly that. `tracker projects --json` is one
# record per folder; its id (the path under tracker/, `hausfold/ci` for a
# sub-project) is what `add --in` takes, carried back in the hidden sixth
# field. Every way out is chained: the box, or a notice, follows at once.
# Prints the id; prints nothing on a dismissal or a typed name that is no
# folder — and says so, because a step that closes with no window and no
# message reads as the palette dropping the keystroke.
pick_project() {
  local rows sel id typed
  rows="$(tracker projects --json 2>>"$LOG" | jq -r '
    (if type == "array" then . else (.projects // []) end)[]
    | (.id // .name // .folder // "") as $id
    | select($id != "")
    | [ $id, "\(.open // .count // 0) open", "folder", "Add here", "Projects", $id ]
    | map(tostring | gsub("[\t\r\n]+"; " ")) | join("\t")' 2>>"$LOG")"
  if [ -z "$rows" ]; then
    notice "No projects yet" "tracker project add <name> makes one — this adds unfiled" "folder.badge.questionmark"
    return 1
  fi
  sel="$(printf '%s\n' "$rows" |
    pounce --grid --chain enter,cmd,opt,ctrl --chain-rows enter,cmd,opt,ctrl \
      -p "$PROMPT — which project?" -i "folder")"
  [ -n "$sel" ] || return 1
  # Runs in a command substitution, so clobbering the two globals costs the
  # caller nothing.
  menu_commit "$sel"
  id="$(menu_field "$MENU_ROW" 6)"
  if [ -z "$id" ]; then
    typed="$(printf '%s' "$MENU_ROW" | tr '\n\t' '  ')"
    notice "No project named $typed" "tracker project add \"$typed\" makes one" "folder.badge.questionmark"
    return 1
  fi
  printf '%s' "$id"
}

# ── drafts ────────────────────────────────────────────────────────────────
# spawn-agent.sh's draft_picker, to the letter. Rows built from
# `pounce drafts … list`, one line per draft by construction; field 6 carries
# the index back, and `get` then hands over the real multi-line text.
draft_picker() {
  local rows sel idx
  rows="$(pounce drafts "$DRAFT_KEY" list 2>/dev/null | while IFS=$'\t' read -r i preview age; do
    printf '%s\t%s\t%s\tUse|cmd:Delete|opt:Clear all\t\t%s\n' \
      "$preview" "$age" "text.quote" "$i"
  done)"
  if [ -z "$rows" ]; then
    notice "No drafts yet" "Text you type here is kept if you dismiss the box" "tray"
    return 1
  fi
  sel="$(printf '%s\n' "$rows" | pounce -p "Drafts — $DRAFT_KEY" -i "tray.full")"
  [ -z "$sel" ] && return 1
  menu_commit "$sel"
  idx="$(menu_field "$MENU_ROW" 6)"
  case "$idx" in '' | *[!0-9]*) return 1 ;; esac
  case "$MENU_ACTION" in
    cmd) pounce drafts "$DRAFT_KEY" rm "$idx" >/dev/null 2>&1; return 1 ;;
    opt) pounce drafts "$DRAFT_KEY" clear >/dev/null 2>&1; return 1 ;;
  esac
  pounce drafts "$DRAFT_KEY" get "$idx"
}

# ── the add itself ────────────────────────────────────────────────────────
# tracker's write report ends with a `file://` line naming the note it wrote.
# The id — the path under tracker/, no .md — is read off THAT rather than
# rebuilt from title and project, because the file name can be sanitized on
# the way in and a rebuilt id would name a note that isn't there. Sets $id
# and $note_path; returns tracker's own exit (1 refused, 2 usage).
do_add() {
  local report rc
  set -- add "$title"
  [ -n "$project" ] && set -- "$@" --in "$project"
  case "$when" in
    now) set -- "$@" --now ;;
    someday) set -- "$@" --someday ;;
  esac
  [ -n "$notes" ] && set -- "$@" --notes "$notes"
  report="$(tracker "$@" 2>>"$LOG")"
  rc=$?
  printf '%s\n' "$report" >>"$LOG"
  [ "$rc" -eq 0 ] || return "$rc"
  note_path="$(printf '%s\n' "$report" | /usr/bin/grep '^file://' | tail -1)"
  note_path="$(pct_decode "${note_path#file://}")"
  if [ -n "$note_path" ]; then
    id="${note_path#*/tracker/}"
    id="${id%.md}"
  else
    id="${project:+$project/}$title"
  fi
  return 0
}

# The receipt, and a door to the note. Through haus-notify, so trill draws it
# when it can and `rules.json` can route it by source. Open carries the note's
# obsidian:// URL, so the banner lands in Obsidian like ⌃↵ does. Needs trill
# ≥ 2026.09.21, which added obsidian to its openable schemes: older trill
# refuses the target at the CLI and the refusal costs the WHOLE send its trill
# rendering, leaving Apple's plain banner with no button at all.
banner() {
  local args
  args=(--source tracker --kind pulse --symbol "$ICON"
        --title "tracker · added"
        --body "$title · ${project:-inbox} · $when")
  [ -n "$note_path" ] && args+=(--action "Open=obsidian://open?vault=$(uri_path "$VAULT")&file=$(uri_path "tracker/$id.md")")
  /run/current-system/sw/bin/haus-notify "${args[@]}" >/dev/null 2>&1
}

# ⌥↵ leaves the box for the drafts list and comes back to it, and ⌘↵ leaves
# it for the project grid and comes back, so this loops rather than falling
# through: neither trip may end the add.
project=""
seed=""
open_after=""
chosen=""
picked=""
id=""
note_path=""
while :; do
  sel="$(ask "$seed")"
  # Dismissed — the daemon filed whatever was typed as a draft.
  [ -n "$sel" ] || exit 0
  menu_commit "$sel"
  action="$MENU_ACTION"
  # Every commit carries the chip's CURRENT value, so it is re-read on each
  # trip round the loop; absent a dial field, later is the CLI's own default.
  if when="$(dial_when "$sel")"; then
    text="$(dial_payload "$sel")"
  else
    when="later"
    text="$MENU_ROW"
  fi
  text="$(printf '%s' "$text" | tr -d '\r')"
  # Line one is the title; anything under it (⇧↵) is the note's body.
  title="${text%%$'\n'*}"
  notes="${text#*$'\n'}"
  [ "$notes" = "$text" ] && notes=""
  title="$(printf '%s' "$title" | /usr/bin/sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  case "$action" in
    opt)
      # Leaving the box deliberately is a COMMIT, not a dismissal, so the
      # daemon files nothing — keep it by hand or ⌥↵ would be the one way to
      # lose a to-do now that every other exit preserves it.
      printf '%s' "$text" | pounce drafts "$DRAFT_KEY" save >/dev/null 2>&1
      if picked="$(draft_picker)"; then
        seed="$picked"
      else
        seed="$text"
      fi
      continue
      ;;
    cmd)
      if chosen="$(pick_project)"; then
        project="$chosen"
        [ -n "$title" ] && break
      fi
      # Nothing typed yet, or the grid was dismissed: the box, text intact,
      # placeholder now naming the project if one was picked.
      seed="$text"
      continue
      ;;
    ctrl)
      open_after=1
      ;;
  esac
  break
done

# Plain ↵ on an empty box is "never mind".
[ -n "$title" ] || exit 0

if ! do_add; then
  notice "Could not add: $title" "tracker refused — why, in $LOG"
  exit 1
fi

if [ -n "$open_after" ]; then
  # Your key, your screen — and no banner, because the note is what you are
  # looking at.
  open "obsidian://open?vault=$(uri_path "$VAULT")&file=$(uri_path "tracker/$id.md")"
  exit 0
fi

banner
# Explicitly, so the add's exit status is the add's and not a notification's.
exit 0
