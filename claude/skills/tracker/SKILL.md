---
name: tracker
description: >-
  Read and write my to-do / issue list from the shell: Today, Inbox, due dates,
  adding, completing, rescheduling. The list is markdown notes in my Obsidian `notes`
  vault (tracker/), one folder per project. Use when I say /tracker, "what's on my
  list", "what's due", "what's in my inbox", "add a todo", "add this to the tracker",
  "remind me to…", "mark X done", "put that on today", "move it to someday", or when
  work we just finished matches a to-do of mine. `later` decides what to file unasked;
  this is the plumbing.
---

# Tracker — markdown notes in the vault, one script over them

```
~/.config/nix/claude/skills/tracker/tracker    # canonical path — always works
tracker                                        # zsh alias, for me at a prompt
```

`tracker help` prints the flag list. Plain bash, live-edited (out-of-store symlink):
fix it in place, no rebuild.

## What the list is

```text
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes/   # the `notes` vault; iCloud → phone
└── tracker/
    ├── tracker.base            # the views: Today · Inbox · Upcoming · Anytime · Someday · Deadlines · Logbook
    ├── inbox/<to-do>.md        # unfiled
    ├── hausfold/
    │   ├── hausfold.md         # the folder note: type: project, the brief, an embedded base of its to-dos
    │   └── <to-do>.md          # type: todo
    ├── buy/ · nas/ · Personal/ · code/ · Work/ …     # a folder per project or area
    └── log/<to-do>.md          # done and canceled, moved here with `done:` and `project:` stamped
```

A to-do's frontmatter, all of it:

```yaml
type: todo
status: open          # open · someday · done · canceled
when: 2026-09-12      # a date → on Today from that day; absent → Anytime
evening: true         # optional
deadline: 2026-09-30  # optional
heading: later        # optional grouping inside a project: later · now · build · decide · …
tags: [fable, haus]   # Obsidian tags; `#fable` = an agent can take it cold
created: 2026-09-12
things: <uuid>        # only on items imported from Things 3
```

The body is the notes; `- [ ]` lines are the checklist. Images go in the body the way
Obsidian pastes them (`![[…]]`) — that is the whole reason the list is here.

**An id is the path under `tracker/` without `.md`**: `hausfold/ship the thing`. Every
read prints it as the last column; `update`/`complete` take it, or any unique
case-insensitive substring of an open item's id or title. Ambiguity prints the
candidates and refuses — show me the candidates, don't pick one.

## Reading

```bash
tracker today                 # when ≤ today, status open — the list I live in
tracker inbox                 # unfiled
tracker upcoming [days]       # default 14
tracker deadlines [days]      # default 30
tracker anytime | someday     # grouped by folder
tracker log [n]               # recently done/canceled
tracker list <project|area>   # one folder, grouped under its `── heading ──` sections
tracker search <text>         # title or body, open and log
tracker show <id|title>       # the whole note, with its links first
tracker link <id|title>       # file:// (clickable in a pane) and obsidian:// (for the app)
tracker projects              # folders with open counts
tracker index [--json]        # every note as one row — the escape hatch; pipe to awk/jq
```

`--json` on any read → `[{id, folder, type, status, when, deadline, heading, tags,
done, title, evening, project}]`.

## Writing

```bash
tracker add "buy cat food" --project buy --when today --tags Errand
tracker add "ship the thing" --project hausfold --heading later --deadline 2026-09-30 \
            --notes "context here" --checklist 'draft|review|merge'
tracker add-project "kitchen reno" --area Personal --notes "<brief>" --todos 'measure|quote|order'

tracker update <id|title> --when tomorrow --add-tags Important --append-notes "…"
tracker update <id|title> --project nas          # moves the file
tracker complete <id|title>                      # status: done, done: <today>, → log/
tracker cancel   <id|title>                      # same, status: canceled
tracker reopen   log/<name>                      # back to its project
```

`--when` takes `today`, `tomorrow`, `someday`, `anytime` or `yyyy-mm-dd`. No project
→ `inbox/`. A project must exist (`tracker projects`); `add-project` makes one.
`DRY_RUN=1 tracker add …` prints the note instead of writing it.

Every write is a file edit: atomic (write beside, `mv`), so iCloud and Obsidian see one
change. Obsidian picks it up live when it is open; the phone when iCloud syncs.

## House rules for you, the agent

1. **Reading is free — do it unasked** when it makes an answer better ("you already
   have a to-do for that, `hausfold/…`"). Reading never touches the screen.
2. **Writing is not free.** Add what I ask for; don't invent to-dos, don't tidy, don't
   bulk-reschedule. Filing follow-ups you discovered is the `later` skill's job.
3. **Completing is a 3/5 action** — I may have wanted it open. One item I named is
   fine, unprompted; more than one, or anything I only implied, gets confirmed first.
4. **Never `rm`.** `cancel` (→ `log/`) is the reversible version; deleting is mine.
5. **End a write report with the `file://` line** `tracker link` prints — that is the
   link I can click in a pane. Never the `obsidian://` one alone: no terminal makes
   it clickable.
6. **Never run `obsidian` (the CLI) or `open`.** The CLI launches the app when it is
   not running, and both take the screen. Files only.
7. **Edit a note by hand only through `tracker`, or `sed`/`cat` on the file if the
   script has no verb for it** — and then keep the frontmatter shape above. A `when:`
   that isn't `yyyy-mm-dd` breaks the Today view for everyone.

## Views (Obsidian)

`tracker/tracker.base` is written by `tracker init` and is mine to reshape in the app;
`tracker init --force` restores the shipped one. Property types (`when`, `deadline`,
`created`, `done` as dates) live in the vault's `.obsidian/types.json` — `init` merges
them in. Each folder note embeds a base filtered on `file.folder == this.file.folder`,
so a project page lists its own to-dos grouped by heading.

## Things 3

`from-things` (beside the script) imported every open Things item once — its `things:`
uuid is on each note, so a re-run only adds what is new. Things' Logbook stayed in
Things; `log/` starts from the switch.
