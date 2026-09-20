#!/bin/bash
# pounce: name = To-dos
# pounce: description = Today and Later, ↵ done · ⌘↵ now ↔ later · ⌥↵ open in Obsidian · ⌃↵ spawn a lane
# pounce: icon = checklist
# pounce: submenu = true
#
# The list: Today, then Later grouped by project as sections (the unfiled
# ones last, as "Later · inbox" — the inbox is the long tail), then Someday.
# Over a row:
#
#   ↵    done
#   ⌘↵   now ↔ later — a Today row goes to later, anything else comes to now
#   ⌥↵   open the note in Obsidian (your key, your screen)
#   ⌃↵   spawn an agent lane for it: `tracker spawn`, a background lane, its
#        own banner when it is up
#
# Type something that matches no row and ↵ ADDS it, unfiled and later — the
# list is also the quickest box. With nothing on the list at all, the one row
# hands you over to Add To-do.
#
# Three reads (`tracker today|later|someday --json`) rather than one `index`:
# the CLI already answers each bucket, arrived dates turned into now included,
# and a second copy of that rule here would drift.
#
# ── the 8-second cliff ───────────────────────────────────────────────────────
# A submenu command commits with a loading disposition: the palette holds a
# skeleton until this script's own `pounce` presents into it, and fades after
# EIGHT SECONDS if nothing comes. So every exit before the picker prints a row
# that says what happened (`bail`) — never a bare exit, which is precisely what
# "the palette did nothing" looks like from the outside (haus's lanes.sh has
# the write-up).
#
# Modelled on haus's modules/launcher/commands/lanes.sh. It lives in
# hosts/mbp/pounce/commands, an out-of-store symlink into
# ~/.config/pounce/commands (shell.nix), so an edit is live with no rebuild.
set -u

# A launchd GUI agent's PATH is bare; resolve our tools (tracker, pounce, jq,
# open) explicitly — the same prelude spawn-agent.sh uses.
export PATH="/etc/profiles/per-user/${USER:-$(id -un)}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

PROMPT="To-dos"
ICON="checklist"
VAULT="$(basename "${TRACKER_VAULT:-notes}")"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/tracker/pounce.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || LOG=/dev/null

# ── menu_commit / menu_field ──────────────────────────────────────────────
# Copied verbatim from haus's modules/launcher/commands/lib/menu-commit.sh —
# the one parse of a pounce menu answer — inline because that lib sits in a
# store path beside spawn-agent.sh that moves on every rebuild. See
# todo-add.sh for the field-by-field contract.
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

# A one-row pounce that says what happened. `bail` is the before-the-picker
# form (see the cliff above) and exits; `notice` is the after-a-pick form.
notice() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-exclamationmark.triangle}" |
    pounce -p "$PROMPT" -i "$ICON" >/dev/null
}
bail() {
  notice "$@"
  exit 0
}

uri_path() { printf '%s' "$1" | jq -Rr 'split("/") | map(@uri) | join("/")'; }
obsidian_url() { printf 'obsidian://open?vault=%s&file=%s' "$(uri_path "$VAULT")" "$(uri_path "tracker/$1.md")"; }

command -v tracker >/dev/null 2>&1 ||
  bail "tracker isn't on PATH" "the list has nothing to read — rebuild haus" "questionmark.circle"
command -v jq >/dev/null 2>&1 ||
  bail "jq isn't on PATH" "the list can't parse tracker's listing" "questionmark.circle"

# One tracker write, stderr to a FILE and never through `$(…)`: `tracker spawn`
# opens a lane whose window inherits our descriptors, and a command
# substitution stays open until every one of them closes (lanes.sh's
# open_lane carries the same note). A refusal becomes a notice in tracker's
# own words, so a wrong id and a project with no repo read differently.
run_tracker() {
  local err rc msg
  err="$(mktemp "${TMPDIR:-/tmp}/tracker-pounce.XXXXXX" 2>/dev/null)" || err=""
  if [ -n "$err" ]; then
    tracker "$@" >>"$LOG" 2>"$err"
    rc=$?
    msg="$(tr '\n' ' ' <"$err" | cut -c1-160)"
    cat "$err" >>"$LOG" 2>/dev/null
    rm -f "$err"
  else
    tracker "$@" >>"$LOG" 2>&1
    rc=$?
    msg=""
  fi
  [ "$rc" -eq 0 ] && return 0
  notice "Could not $1: $title" "${msg:-tracker exited $rc} — the log is $LOG"
  return "$rc"
}

# ── the rows ─────────────────────────────────────────────────────────────
# One row per to-do, pounce's six-column TSV:
#   title \t description \t icon \t actions-spec \t section \t payload
# The payload is "<bucket>:<id>" — ONE hidden field, the bucket in front (a
# bucket name never holds a colon; an id may), so ⌘↵ knows which way to flip
# without a second read. A row's OWN spec is the only thing pounce consults
# for a modifier held over it (`--actions` labels the row-less bar alone), so
# the four Returns are spelled on every row, ⌘↵'s label by bucket.
# $1 the listing verb · $2 the section, or "" for "Later · <project>" · $3 icon
rows_of() {
  local json
  json="$(tracker "$1" --json 2>>"$LOG")" ||
    bail "tracker $1 failed" "why, in $LOG" "questionmark.circle"
  printf '%s' "$json" | jq -r --arg section "$2" --arg icon "$3" '
    def clean: tostring | gsub("[\t\r\n]+"; " ");
    def where: if (.project // "") == "" then "inbox" else .project end;
    (if type == "array" then . else [] end)
    | (if $section == "" then
         sort_by([ (if (.project // "") == "" then 1 else 0 end), (.project // ""), (.title // .id) ])
       else . end)
    | .[]
    | (.bucket // "later") as $b
    | [ (.title // .id),
        ([ (if $section != "" then where else empty end),
           (if (.due // "") != "" then "due \(.due)" else empty end),
           ((.tags // []) | map("#" + .) | join(" ") | select(. != ""))
         ] | join(" · ")),
        $icon,
        "Done|cmd:\(if $b == "now" then "Later" else "Now" end)|opt:Open in Obsidian|ctrl:Spawn lane",
        (if $section != "" then $section else "Later · \(where)" end),
        "\($b):\(.id)" ]
    | map(clean) | join("\t")' 2>>"$LOG"
}

rows="$(
  rows_of today "Today" "circle.fill"
  rows_of later "" "circle"
  rows_of someday "Someday" "circle.dotted"
)"

# Nothing anywhere: one row that hands over to Add To-do (the sibling script
# beside this one in the same symlink farm). Its payload bucket is `add`, so
# the commit below routes it; typed text on this row still adds directly.
# Chained, because Add To-do's box follows the pick within milliseconds.
chain=""
if [ -z "$rows" ]; then
  rows="$(printf 'Nothing on the list\t%s\t%s\tAdd\tTo-dos\tadd:' \
    "today, later and someday are all clear — ↵ opens Add To-do, or type one here" \
    "checkmark.circle")"
  chain="--chain-rows enter"
fi

# `--actions` is the bar for a query matching NO row — the only state in
# which typed text commits — so it names what ↵ does there: add.
# shellcheck disable=SC2086
selected="$(printf '%s\n' "$rows" |
  pounce -p "$PROMPT" -i "$ICON" --actions "Add to-do" $chain)" || exit 0
[ -n "$selected" ] || exit 0

menu_commit "$selected"
action="$MENU_ACTION"
title="$(menu_field "$MENU_ROW" 1)"
payload="$(menu_field "$MENU_ROW" 6)"

# ── typed text: add it ───────────────────────────────────────────────────
# A free-text commit is tab-free, so the sixth field is empty — that, not the
# committing key, is what tells it from a row. Line one is the title; the
# rest of a ⇧↵ answer is the note's body.
if [ -z "$payload" ]; then
  text="$(printf '%s' "$MENU_ROW" | tr -d '\r')"
  title="${text%%$'\n'*}"
  notes="${text#*$'\n'}"
  [ "$notes" = "$text" ] && notes=""
  title="$(printf '%s' "$title" | /usr/bin/sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$title" ] || exit 0
  set -- add "$title"
  [ -n "$notes" ] && set -- "$@" --notes "$notes"
  run_tracker "$@" || exit 1
  # The receipt: the palette is gone and the row it made is in the NEXT open.
  /run/current-system/sw/bin/haus-notify --source tracker --kind pulse --symbol checkmark.circle \
    --title "tracker · added" --body "$title · inbox · later" >/dev/null 2>&1
  exit 0
fi

bucket="${payload%%:*}"
id="${payload#*:}"

case "$bucket" in
  add)
    add="$(dirname "$0")/todo-add.sh"
    [ -x "$add" ] && exec "$add"
    exec pounce run cmd:todo-add
    ;;
esac
[ -n "$id" ] || exit 0

case "$action" in
  cmd)
    if [ "$bucket" = now ]; then verb=later; else verb=now; fi
    run_tracker "$verb" "$id" || exit 1
    ;;
  opt)
    open "$(obsidian_url "$id")"
    ;;
  ctrl)
    # A lane in the background — the to-do's `repo:` or its project's decides
    # where; a project with neither is tracker's refusal, shown as a notice.
    # The "lane is up" banner is tracker's own.
    run_tracker spawn "$id" || exit 1
    ;;
  *)
    run_tracker "done" "$id" || exit 1
    ;;
esac
exit 0
