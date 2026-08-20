---
name: things
description: >-
  Read and write my Things 3 to-dos from the shell — what's on Today, what's in the
  Inbox, what's due, and adding/completing/rescheduling items. Use when I say /things,
  "what's on my list", "what's due", "what's in my inbox", "add a todo", "add this to
  Things", "remind me to…", "mark X done", "put that on today", "move it to someday",
  or when a piece of work we just finished obviously corresponds to a to-do of mine.
  Also use it to file follow-ups you discover while working, if I ask you to.
---

# Things 3 — read from SQLite, write through the URL scheme

One helper does all of it:

```
~/.config/nix/claude/skills/things/things    # canonical path — always works
things                                       # zsh alias, for me at a prompt
```

Run `things help` if you need the full flag list. It's a plain bash script in this
skill's directory, live-edited (out-of-store symlink) — fix it in place, no rebuild.

## The two halves, and why they're different

| | Path | Why |
|---|---|---|
| **Read** | `sqlite3 -readonly` on the app's own database | No AppleScript, so no Automation permission prompt, no launching the app, and **nothing takes focus from whoever is at the keyboard**. Fast enough to query in a loop. |
| **Write** | `open -g "things:///…"` ([URL scheme](https://culturedcode.com/things/support/articles/2803573/)) | The only supported way to mutate. `-g` keeps Things in the background. |

**Never write to that SQLite file.** Things keeps its own sync journal alongside it;
a hand-written row desyncs the account across Mac/iPhone/iPad and there is no clean
repair. The script only ever opens it `-readonly` — keep it that way.

Writes are **asynchronous**: `open` returns before Things has applied the URL. The
script already sleeps ~0.6s; if you need to confirm a write landed, re-read
(`things show "<title>"`), don't assume.

## Reading

```bash
things today                 # everything scheduled today or overdue (this is the list I live in)
things inbox                 # unfiled
things upcoming [days]       # default 14
things deadlines [days]      # default 30, sorted by due date
things anytime | someday
things logbook [n]           # recently completed/canceled, with the date
things list <project|area>   # e.g. `things list hausfold` — grouped under the project's own `── heading ──` sections
things search <text>         # title + notes, open and completed
things show <id|title>       # one item in full: notes, checklist, tags, project
things projects | areas | tags
things sql '<select …>'      # escape hatch; refuses anything but SELECT/WITH
```

Every read line starts with the item's id — that's what `update`/`complete` take.
Add `--json` to any read for machine-readable output
(`{id, when, deadline, tags, list, title, heading}`).

`list` and `show <project>` print the project's headings as `── name ──` section
breaks, in the order Things shows them; to-dos above the first heading come first.
The other lists (`today`, `search`, …) span projects, so they stay flat — read
`heading` from `--json` if you need it there.

## Writing

```bash
things add "buy cat food" --when today --tags Errand --list Personal
things add "ship the thing" --deadline 2026-09-01 --notes "context here" \
                            --checklist 'draft|review|merge'
things add-project "kitchen reno" --area Personal --todos 'measure|quote|order'

things update <id|title> --when tomorrow --add-tags Important --append-notes "…"
things complete <id|title>
things cancel   <id|title>

things json '<array>' | <file> | -    # bulk / nested projects, per the URL-scheme docs
```

`--when` takes what Things takes: `today`, `tomorrow`, `evening`, `anytime`,
`someday`, `2026-09-01`, `2026-09-01@14:00`, or natural language like `next tuesday`.
`--deadline` is `yyyy-mm-dd`.

`<id|title>` resolves a substring against open items and **refuses when it's
ambiguous**, printing the candidates. When that happens, show me the candidates and
ask — don't pick one.

`DRY_RUN=1` prints the URL instead of firing it. Use it whenever you're unsure what a
command will do; the URL is fully readable.

The auth token that `update`/`json` need is read out of the database automatically
(Things → Settings → General → Enable Things URLs). Never print it.

## House rules for you, the agent

1. **Reading is free — do it unasked** when it makes an answer better ("you already
   have a to-do for that, dated 2026-08-09"). Reading never touches the screen.
2. **Writing is not free.** Adding, completing, and rescheduling change a list I
   actually work from. Add what I ask for; don't invent to-dos, don't tidy, don't
   bulk-reschedule. Filing follow-ups you discovered needs me to have asked.
3. **Completing is a 3/5 action** — I may have wanted it open. One item I named is
   fine, unprompted; more than one, or anything I only implied, gets confirmed first.
4. **Never delete.** The URL scheme has no delete, and that's a feature. `cancel`
   (→ Logbook) is the reversible version; deleting is mine to do in the app.
5. **Quote the id** when you report a write, so I can `things show` it.
6. **Don't foreground Things.** No `--reveal`, no plain `open`, unless I ask to see
   it. `open -g` is the default for a reason (see the desktop rules in CLAUDE.md).

## When the script is the wrong tool

- **Anything that must move Things' UI** (reveal an item, open a list) — that's
  `things:///show?id=…`, and it steals focus, so ask me first.
- **Repeating to-dos** can't be updated by the URL scheme at all; Things ignores
  `when`/`deadline`/`completed` on them. If an update silently does nothing, that's
  usually why — say so instead of retrying.
- **iPhone/iPad state** isn't here. This reads *this Mac's* local database; if sync
  is behind, so is the answer.

## Schema notes (for when you need `things sql`)

`TMTask` holds to-dos, projects (`type=1`) and headings (`type=2`).
`status`: 0 open · 2 canceled · 3 completed. `trashed`: 1 = in Trash.
`start`: 0 Inbox · 1 Anytime/scheduled · 2 Someday; `startBucket=1` means Evening.
`startDate`/`deadline` are **bit-packed, not epochs**: `year<<16 | month<<12 | day<<7`.
`creationDate`/`stopDate` are plain unix epochs.
A to-do under a heading has `project` NULL — resolve it through
`TMTask.heading → TMTask.project`, which is what the script's joins do.
