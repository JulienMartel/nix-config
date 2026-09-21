---
name: tracker
description: >-
  Read and write my to-do list from the shell: Today, Later, Someday, due dates,
  adding, completing, rescheduling, spawning a lane for one. The list is markdown
  notes in my Obsidian `notes` vault (tracker/), one folder per project, Bases for
  the views. Use when I say /tracker, "what's on my list", "what's due", "what's in
  my inbox", "add a todo", "add this to the tracker", "remind me to…", "mark X
  done", "put that on today", "move it to someday", "spawn that todo", or when work
  we just finished matches a to-do of mine. `later` decides what to file unasked;
  this is the plumbing.
---

# Tracker — markdown notes in the vault, one binary over them

```
tracker                      # on PATH (a Go binary from ~/.config/nix/pkgs/tracker)
tracker help                 # the verb list
```

The manual is `~/.config/nix/pkgs/tracker/README.md`: the schema, the views, every
verb, the TUI keys. What follows is what an agent needs.

## What the list is

```text
notes/tracker/
├── tracker.base            # the views: Today · Later · Upcoming · Someday · Due · Inbox · Done · Project
├── <to-do>.md              # unfiled ("inbox") = the root
├── hausfold/
│   ├── hausfold.md         # the folder note: type: project, repo:, the brief, ![[tracker.base#Project]]
│   ├── <to-do>.md
│   └── <sub-project>/      # a folder in a folder; a folder of folders is an area
└── log/                    # the archive `archive` and `project done` move closed notes into
```

A to-do, all of it:

```yaml
when: later          # REQUIRED · now | later | someday | YYYY-MM-DD (later until that day, then now)
due: 2026-09-30      # optional
done: 2026-09-20     # set = closed that day · `dropped:` instead when abandoned
tags: [fable]        # #fable = an agent can take it cold · #decide / #build = the kind of work
created: 2026-09-20
lane: workshop/x     # written by `tracker spawn`
```

The body is the notes; `- [ ]` lines are the checklist. Closing never moves a file
and there is no status field: `done:` set is done. **An id is the path under
`tracker/` without `.md`** (`hausfold/ship the thing`, or `buy milk` unfiled); every
verb takes it, or any unique case-insensitive substring of an open item's id or
title. Ambiguity prints the candidates and exits 1 — show me them, don't pick.

## Reading

```bash
tracker today                 # when: now, or a date that has arrived — the list I live in
tracker later | someday       # grouped by project
tracker upcoming [days]       # dated, default 14 · tracker due [days]  deadlines, default 30
tracker inbox                 # unfiled · tracker done [n]  recently closed
tracker list <project>        # one folder (subfolders in), grouped now · scheduled · later · someday
tracker projects              # folders with open counts · tracker search <text>
tracker show <id>             # the note, links first · tracker link <id>  file:// then obsidian://
tracker index                 # every note, one row — the escape hatch
```

`--json` on any read → `[{id, title, folder, project, when, bucket, due, done,
dropped, tags, created, lane, repo, path}]`; `bucket` is `now · scheduled · later ·
someday`.

## Writing

```bash
tracker add "buy cat food" --in buy --now --tags errand
tracker add "ship the thing" --in hausfold --due 2026-09-30 --notes "context" --checklist 'draft|review|merge'
tracker project add "kitchen reno" --in Personal --notes "<brief>" --todos 'measure|quote|order'
tracker project done "kitchen reno"      # finished: its notes → log/, the folder goes

tracker now | later | someday <id>       tracker when <id> tomorrow|+3d|2026-10-01
tracker due <id> 2026-09-30|none         tracker move <id> nas · rename · tag <id> +a -b · note <id> "…"
tracker done <id> · drop <id> · reopen <id>
tracker update <id> [--when …] [--due …] [--add-tags …] [--in …] [--append-notes "…"]
tracker spawn <id>                       # a lane for it: prompt from the note, `lane:` stamped, banner when live
```

No `--in` → unfiled. A project must exist (`tracker projects`); `project add` makes
one, `--in` nests it. `--dry-run` / `DRY_RUN=1` on `add`, `spawn`, `archive`,
`migrate`, `project done`. Every write is atomic and ends with a `file://` line.

## House rules for you, the agent

1. **Reading is free — do it unasked** when it makes an answer better ("you already
   have a to-do for that, `hausfold/…`"). Reading never touches the screen.
2. **Writing is not free.** Add what I ask for; don't invent to-dos, don't tidy, don't
   bulk-reschedule. Filing follow-ups you discovered is the `later` skill's job.
3. **Completing is a 3/5 action** — I may have wanted it open. One item I named is
   fine, unprompted; more than one, or anything I only implied, gets confirmed first.
4. **Never `rm`.** `drop` is the reversible version (`reopen` undoes it); deleting is
   mine. `archive` only moves closed notes and only when asked.
5. **Retiring a project is asked for, never inferred.** `tracker project done
   <name>` is how a finished one leaves: its closed to-dos and its brief go to
   `log/`, and the folder goes with them, which is the only thing that takes the
   row off `tracker projects`. It refuses while anything is open, and `tracker
   reopen <id>` on the brief puts the whole project back. Zero open to-dos is not
   by itself a reason to run it — a project can sit empty between passes.
6. **End a write report with the `file://` line** the verb prints — the link I can
   click in a pane. Never the `obsidian://` one alone: no terminal makes it clickable.
7. **Never run `obsidian` (the CLI) or `open`.** Both take the screen. Files only.
   `tracker spawn` is fine: it spawns in the background and a banner tells me.
8. **Edit a note only through `tracker`**, or `sed`/`cat` on the file if it has no
   verb — keeping the shape above. A `when:` that is not one of the four forms falls
   out of every view for everyone.

## Views (Obsidian)

`tracker.base` is written by `tracker init`, mine to reshape in the app, and
`--force` restores it. Folder notes embed `![[tracker.base#Project]]` — one base,
every project, `this` being the embedding note. The `⚡ spawn` column is the plugin's
`obsidian://tracker?spawn=…` handler calling `tracker spawn`. The phone closes a
to-do by setting `done` to today; no sweep, nothing to finish. The CLI turns an
arrived date into `now` on every read, and the Today view catches one the phone
reached first.

## Things 3 (history)

Things 3 is gone — off this Mac, out of the roster, and its `r` hotkey with it.
A bash `from-things` imported it whole in 2026-07, in the old shape; `tracker
migrate` converts that shape to this one and is idempotent. Both scripts lived
in `legacy/` here until the import was done with; `git log -- claude/skills/tracker/legacy`
has them if the history is ever wanted. The import left a `things:` uuid on each
note, and `tracker migrate` now strips that too.
