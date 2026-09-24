#!/bin/bash
# pounce: name = Spawn To-do Lane
# pounce: description = An agent lane for one to-do — the tracker's ⚡ column links here
# pounce: icon = bolt.fill
# pounce: mutates = true
#
# The desktop end of the ⚡ column in tracker.base, which links
#
#   pounce://run?item=cmd:tracker-spawn&arg=<vault path of the to-do>
#
# pounce hands the arg over as $1, argv and never a shell, and `tracker spawn`
# takes the vault path as it is (`tracker/<id>.md` resolves like `<id>`). The
# link is confirmed on screen by pounce itself (`urlScheme.confirm`), naming
# Obsidian and the path, so nothing here asks again.
#
# From the palette there is no $1: say so in a banner rather than guess a
# to-do. To-dos' ⌃↵ is the palette's way to spawn one.
#
# The "lane is up" banner is tracker's own; this only speaks on failure. It
# lives in hosts/mbp/pounce/commands, an out-of-store symlink into
# ~/.config/pounce/commands (shell.nix), so an edit is live with no rebuild.
set -u

# A launchd GUI agent's PATH is bare — the same prelude todos.sh uses.
export PATH="/etc/profiles/per-user/${USER:-$(id -un)}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/tracker/pounce.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || LOG=/dev/null

banner() {
  haus-notify --source tracker --kind pulse --symbol exclamationmark.triangle \
    --title "$1" --body "$2" >/dev/null 2>&1
}

id="${1-}"
if [ -z "$id" ]; then
  banner "tracker · no to-do" "Spawn To-do Lane runs from a ⚡ link; in the palette, ⌃↵ on a row in To-dos"
  exit 2
fi
command -v tracker >/dev/null 2>&1 || {
  banner "tracker isn't on PATH" "nothing to spawn with — rebuild haus"
  exit 1
}

# stderr to a FILE and never through `$(…)`: the lane's window inherits our
# descriptors, and a command substitution stays open until every one of them
# closes (todos.sh's run_tracker carries the same note).
err="$(mktemp "${TMPDIR:-/tmp}/tracker-spawn.XXXXXX" 2>/dev/null)" || err=/dev/null
tracker spawn "$id" >>"$LOG" 2>"$err"
rc=$?
msg=""
if [ "$err" != /dev/null ]; then
  msg="$(tr '\n' ' ' <"$err" | cut -c1-160)"
  cat "$err" >>"$LOG" 2>/dev/null
  rm -f "$err"
fi
[ "$rc" -eq 0 ] && exit 0
banner "tracker · could not spawn" "${msg:-tracker exited $rc} — the log is $LOG"
exit "$rc"
