# tracker

My to-do list: one markdown note per to-do in the Obsidian `notes` vault
(iCloud, so the phone has it), one folder per project, Obsidian Bases for the
views, one Go binary for the shell: a CLI for agents and scripts, a fullscreen
TUI for me. Two pounce commands, a tiny Obsidian plugin and a share-sheet
Shortcut on the phone sit on top of it. Nothing here is a Things 3 clone: the
base is five properties, and everything else (areas, boards, the logbook,
lanes) falls out of Obsidian doing what it already does.

```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes/   # the vault
└── tracker/
    ├── tracker.base            # the views · written by `tracker init`
    ├── <to-do>.md              # unfiled = in the root ("inbox")
    ├── hausfold/
    │   ├── hausfold.md         # the folder note: type: project, the brief, ![[tracker.base#Project]]
    │   ├── <to-do>.md
    │   └── ci/                 # a folder inside a folder is a sub-project; a folder of folders is an area
    ├── Personal/ · Work/ · buy/ · code/ · nas/
    └── log/                    # the archive: what `tracker archive` and `project done` moved out of the way
```

## The base: a to-do

```yaml
---
when: later          # REQUIRED · now | later | someday | YYYY-MM-DD
repeat: weekly       # optional · it comes back when you complete it
due: 2026-09-30      # optional · a hard deadline
done: 2026-09-20     # set = closed on that day   (dropped: 2026-09-20 = abandoned instead)
tags: [fable]        # optional · #fable = an agent can take it cold · #decide / #build = the kind of work
created: 2026-09-20
---
The notes. `- [ ]` lines are the checklist. Images the way Obsidian pastes them.
```

- **`when`** is the one field that matters and it is never empty: `now` (on
  Today), `later` (the default), `someday` (parked), or a date, which means *later until
  that day, then now*. The CLI turns an arrived date into `now` on every read,
  and the Bases Today view catches one the phone reached first.
- **Closed is a date, not a status.** `done:` or `dropped:` set means closed;
  the note stays where it is. Nothing moves on completion, so the phone can
  close a to-do completely with one property. `tracker archive` sweeps closed
  notes older than 30 days into `log/` (stamping `project:` so history keeps
  its list), and the Done view is by `done`, wherever the file sits.
- **A project ends the same way, with `tracker project done <name>`.** Its
  closed to-dos go to `log/` the way `archive` sends them, its folder note is
  demoted to a closed note — `done:` today, `project:` stamped, the Project
  view line dropped — and follows them, and the empty folder goes, which is
  what finally takes the row off `tracker projects`: that list walks the
  directory tree, so a project lives as long as its folder does. The brief
  keeps its body and reads in Done as the day the work ended. Open to-dos, a
  sub-project or a file that is not a note refuse the whole thing; `tracker
  reopen <id>` on the brief is the inverse and puts the project back whole.
- **`repeat` brings it back.** `daily | weekly | monthly | yearly | every N
  days` — and `every N weeks | months | years`, which is the same rule.
  Completing a repeating to-do closes that note exactly as it always did
  **and** writes a fresh one for the next occurrence: same folder, same body
  with the checklist emptied, its own `created:`, no `done:` or `lane:`. A
  closed note is never rolled forward; closed is still a date, not a status.
  The next date counts from the note's own `when:`, never from the day you got
  round to it, and is advanced until it is past today — so a weekly chore done
  three days late lands on its next slot, not on a backlog of missed ones. A
  `due:` moves by the same number of days, keeping its lead time. `drop` is how
  a series ends. Since the occurrence is a new file and the closed one still
  holds the plain name, its id gains a ` (2)` — ` (3)` and up while earlier
  ones are still about, until `tracker archive` sweeps them into `log/` and
  frees the name. `title:` is kept, so the title stays what every view shows
  and what you type.
- **The inbox is what has not been triaged**: no project *and* `when: later`,
  which is what a fresh capture is. Giving it either — a project, or `now` /
  `someday` / a date — takes it out, the way Things 3's inbox emptied when a
  task got a home. An unfiled to-do you have decided about still lives in the
  root; `tracker projects` counts every one of them under `(unfiled)`, which
  is why that number is the larger one.
- **No project = the root of `tracker/`.** A folder is a project; its folder
  note (`<folder>/<folder>.md`) carries `type: project`, the brief, an optional
  `repo:` (what `tracker spawn` spawns on), and embeds the Project view. A
  folder inside a folder is a sub-project; a folder of folders is an area. No
  `area` type, no `heading`, no `status`, no `evening`.
- **Optional extras**, all written by verbs: `title:` when the file name had to
  be sanitized, `lane: <repo>/<name>` once `tracker spawn` ran, `repo:` on a
  to-do to override its project's, `project:` only on archived notes.

An **id** is the path under `tracker/` without `.md`: `hausfold/ship the
thing`, or `buy cat food` for an unfiled one. Every verb that takes one also
takes a unique case-insensitive substring of an open item's id or title;
ambiguity prints the candidates and exits 1.

### Which notes are to-dos

Every `.md` under `tracker/` except folder notes (`type: project`, or the
note named after its folder). `log/` notes are to-dos too, closed. A note
with no `when` (made by hand in Obsidian) is `later`.

## Views (`tracker.base`)

`tracker init` writes it; `--force` restores the shipped one. Property types
(`due`, `done`, `dropped`, `created` as dates; `when` and `repeat` as text) go
in `.obsidian/types.json`. Views: **Today** · **Later** (grouped by project) ·
**Upcoming** (dated) · **Someday** · **Due** · **Inbox** (untriaged) · **Done** ·
**Project** (the one folder notes embed as `![[tracker.base#Project]]`; `this`
is the embedding note, so one base serves every project). A `⚡ spawn` column
links to `obsidian://tracker?spawn=<path>`, which the plugin turns into
`tracker spawn`. When Obsidian 1.14 (Bases kanban) is public, a **Board** view
grouped by `when` gives drag-and-drop now ↔ later ↔ someday.

## CLI

```
tracker                          # a terminal → the TUI; otherwise `today`
tracker today | later | someday | upcoming [days=14] | due [days=30] | inbox | done [n=20]
tracker list <project>           # one folder, subfolders included, grouped now · scheduled · later · someday
tracker projects                 # every folder with open counts, indented by depth
tracker search <text>            # title or body, open and closed
tracker show <id>                # the note, id and links first
tracker link <id>                # file:// (clickable in a pane) then obsidian://
tracker index                    # every note, one row — the escape hatch

tracker add <title> [--in <project>] [--now | --someday | --when <date|today|tomorrow|+3d>]
                    [--due <date>] [--repeat <spec>] [--tags a,b] [--notes <text>]
                    [--checklist 'a|b'] [--edit]
tracker now | later | someday <id>          tracker when <id> <now|later|someday|date>
tracker due <id> <date|none>                tracker done <id> · drop <id> · reopen <id>
tracker repeat <id> <daily|weekly|monthly|yearly|every N days|none>
tracker move <id> <project|unfiled>         tracker rename <id> <title>
tracker tag <id> +a -b                      tracker note <id> <text>       (append)
tracker edit <id>                           ($EDITOR, then re-read)
tracker update <id> [--when …] [--repeat …] [--due …] [--tags …] [--add-tags …] [--in …] [--title …] [--append-notes …]
tracker project add <name> [--in <parent>] [--repo <path>] [--notes <brief>] [--todos 'a|b']
tracker project set <name> repo=<path>      tracker promote <id>            (to-do → project folder)
tracker project done <name>                 # finished: its notes → log/, the folder goes
tracker spawn <id> [--repo <path>] [--follow] [--again]   # a lane for this to-do, background, banner when live
tracker archive [--older 30] [--dry-run]    tracker migrate [--dry-run]     tracker init [--force]
```

Aliases kept for the skills: `complete`→`done`, `cancel`→`drop`, `anytime`→`later`,
`add-project`→`project add`, `--project`→`--in`, `--deadline`→`--due`.

- `--json` on any read → `[{id, title, folder, project, when, bucket, repeat,
  due, done, dropped, tags, created, lane, repo, path}]`. `bucket` is `now` · `scheduled`
  · `later` · `someday`; `project` is the folder's first segment, `""` unfiled.
  `projects --json` is its own shape, one row per folder:
  `[{id, name, depth, open, repo, path}]`, the inbox first with `id: ""`.
- `DRY_RUN=1` (or `--dry-run`) on `add`, `archive`, `migrate`, `spawn`.
- Exit codes: 0 ok · 1 nothing matched / refused · 2 usage.
- Every write is atomic (write beside, rename) so iCloud and Obsidian see one
  change, and every write report ends with the `file://` line.
- `TRACKER_VAULT` / `TRACKER_DIR` point it elsewhere (tests, a copy).

### `tracker spawn <id>`

The `later` skill's step 4 as a verb. Resolves the repo: the to-do's `repo:`,
else the nearest ancestor folder note's, else `--repo`, else refuses naming the
project to set it on. Writes the prompt (title, the body, then `tracker: <id>`
and `On /ship: tracker done "<id>"`) and runs it the way haus's Spawn Agent
does: `HAUS_LANE_BACKGROUND=1 scruff spawn <repo> --derived-name <slug>
--agent <scruff agent default> --prompt-file -` (`--follow` clears the
background flag). Then `when: now`, `lane: <repo>/<name>` on the note, and a
`haus-notify --source tracker --kind pulse` banner with a `Go to lane` action.
A to-do that already has a `lane:` refuses unless `--again`.

## TUI

`tracker` on a terminal opens it: alt-screen, nebelung colours (mocha / latte
by the terminal's background), resizes live, never reaches the last column.

```
┌ tracker ─────────────────────────────────────────────────────────────────┐
│ Today 4  Later 61  Someday 17  Upcoming 6  Due 2  Inbox 33  Done │ ⚡ 1 │
├──────────────┬───────────────────────────────────────────┬──────────────┤
│ ● Today      │ hausfold                                   │ windows wri… │
│ ○ Later      │ ● windows writes two other rooms' pa… #fable│              │
│ ◌ Someday    │ ● a red tap gate after a green scruff…      │ Where: haus  │
│ ◔ Upcoming   │ Personal                                    │ · modules/…  │
│ ! Due        │ ○ set a goal for WPM on touch typing        │              │
│ ▸ Inbox      │ ○ setup a strict sleep regiment    due 9/30 │ Next: gate…  │
│ ✓ Done       │                                             │              │
│ ──────────   │                                             │ [ ] check 1  │
│ hausfold  14 │                                             │              │
│   ci       1 │                                             │              │
│ Personal  21 │                                             │              │
├──────────────┴───────────────────────────────────────────┴──────────────┤
│ a add  ⏎ open  x done  n now  l later  s someday  w when  d due  m move │
│ S spawn  e edit  o obsidian  / filter  ? help  q quit                    │
└──────────────────────────────────────────────────────────────────────────┘
```

- Three panes: lists (the seven views, then the project tree with open counts),
  the list (rows grouped by project or by bucket, `● now ◔ scheduled ○ later ◌
  someday`, due dates right-aligned, `#tags` muted), the note (rendered body,
  checklist ticks toggleable with space). Under 100 columns the note pane
  folds under the list; under 70 the sidebar becomes a top tab strip.
- Keys, navigation first: `⇥`/`⇧⇥` (or `[`/`]`) walk the view tabs and `1`-`7`
  jump straight to one; `←`/`→` move between the three panes, `⏎` goes one pane
  right, `esc` comes back to the list; `j/k ↑↓` move, `g`/`G`, `⌃d`/`⌃u` page.
  Clicking works too: a tab, a sidebar row, a list row (a second click on the
  selected row opens it), and the wheel scrolls whatever is under the pointer.
  Then, on the selected to-do: `a` add (a one-line box; `⇥` cycles
  now/later/someday, `⌃d` sets due) · `x`/`space` done · `X` drop · `R` reopen ·
  `n` `l` `s` now/later/someday · `w` when (date) · `d` due · `m` move to
  another project (fuzzy picker) · `t` tags · `r` rename · `S` spawn a lane ·
  `e` `$EDITOR` · `o` open in Obsidian (my key, my screen) · `u` undo the last
  write · `/` filter · `A` archive · `?` help · `q` quit. No key means two
  things: `l` is later everywhere, never a pane move.
- The vault is watched (fsnotify): a change from Obsidian or the phone repaints
  within a second. Writes go through the same code the CLI uses.

## Pounce

`hosts/mbp/pounce/commands/` (out-of-store symlinks into
`~/.config/pounce/commands`, live-edited):

- **Add To-do** (`todo-add.sh`, leader + `a`, palette "todo"): one box.
  `⇥` dials now / later / someday, `↵` adds unfiled, `⌘↵` picks a project first
  (a grid of folders), `⌃↵` adds and opens it in Obsidian, `⌥↵` drafts. Trill
  banner with an Open action.
- **To-dos** (`todos.sh`, palette): Today, then Later by project as sections;
  `↵` done · `⌘↵` now ↔ later · `⌥↵` open in Obsidian · `⌃↵` spawn a lane.

## Obsidian plugin

`obsidian-plugin/` — plain JS, no build, installed into
`.obsidian/plugins/tracker/` by `tracker init` (and enabled). It does only what
Bases cannot: commands **Tracker: quick add** (title + when), **done**,
**drop**, **now / later / someday**, **spawn lane** (desktop: runs `tracker
spawn`), and the `obsidian://tracker?spawn=<path>` · `?done=<path>` ·
`?add=<title>[&when=][&in=][&due=][&repeat=][&tags=a,b][&notes=<body>]`
protocol the ⚡ column, pounce and the phone use. Mobile gets the commands, not
spawn. **done** repeats here too — same date math, same bytes as the CLI — so
a chore closed on the phone comes back without waiting for a Mac.

`?add=` takes everything `tracker add` takes but the checklist, and writes the
same bytes for it: same key order, same YAML quoting, same file name, the
CLI's `now | later | someday | today | tomorrow | +Nd | YYYY-MM-DD` for `when`
and `due`, its grammar for `repeat`. A `due` or a `repeat` that is none of
those is refused in a Notice and the to-do is still made — a capture never
fails on a bad parameter. An `?add=` with no
title opens quick add holding whatever else came with it, so a share that
arrives without one keeps its URL.

## Capture from the phone

Share a link or a selection from any iOS app and it lands unfiled in
`tracker/`, filed later on the Mac — what Things 3's share extension did. A
Shortcut in the share sheet writes the note itself, straight into the vault
folder over iCloud: nothing launches, it works on a plane, and the Mac sees
the file as soon as iCloud carries it.

Only a person can build a Shortcut, so the phone half is a wizard:

```
bash pkgs/tracker/scripts/setup-ios-capture          # ~10 min, all of it on the phone
bash pkgs/tracker/scripts/setup-ios-capture verify   # just the watch-for-it stage
```

Ten actions: `Get Name` of the share, four regex `Replace Text` to make it a
file name, `Format Date` for `created:`, one `Text` holding the note, `Set
Name`, `Save File` into `tracker/`. The last stage watches the vault from the
Mac until the first capture lands and prints it. What it writes:

```yaml
---
when: later          # unfiled + later = the inbox
created: 2026-09-20  # yyyy-MM-dd — the Inbox view sorts on it
title: "Why Nix flakes: a field guide | example.com"
---
https://example.com/nix-flakes
```

The phone always writes `title:`, where the CLI writes it only when the file
name had to be sanitized: one line, and a shared title never loses its colons.
`testdata/capture.golden.md` is that note and both halves are held to it —
`internal/vault/capture_test.go` for the CLI, `obsidian-plugin/main.test.js`
for the plugin. A note with nothing but a body still reads as an unfiled
`later` to-do, so a capture that writes less than this is not lost.

### Why the Shortcut writes the file

| | taps | Obsidian opens | offline | two at once |
|---|---|---|---|---|
| **a Shortcut writing the `.md`** | **2** | **no** | yes | a name twice = a second note, never a lost one |
| Obsidian's own Share to Obsidian | 3–4 | no | yes | same, but one global destination for every share, and no `when:` |
| a Shortcut calling `obsidian://tracker?add=` | 2 + the launch | **yes, every time** | yes | Obsidian's own write |
| Reminders + a Mac-side importer | 2, or none by Siri | no | yes | CloudKit, genuinely conflict-free |

Obsidian opening is what kills a capture habit, which rules out the protocol
for the common case and leaves it the fallback below. Share to Obsidian can
only have one destination folder for the whole vault, so `tracker/` would
swallow every clipping. Reminders wins on conflicts and on Siri, and loses on
the thing that matters more: the to-do would not exist in the tracker until a
Mac woke up and drained it, and a second store of truth is the one thing this
list does not have.

The iCloud file race is the honest cost: two devices writing the *same* name
in the same second get a conflicted copy, which reads as one extra to-do in
the inbox. Visible, and deletable in a tap.

### If `Save File` fights you

The protocol path, five actions, as a second Shortcut: `Get Name` →
`URL Encode` it → `URL Encode` the `Shortcut Input` → `Text`:
`obsidian://tracker?add=[name]&notes=[input]` → `Open URLs`. Obsidian
foregrounds and the plugin writes the note, with the CLI's own sanitizing and
`(2)` collision handling instead of the Shortcut's. Add `&in=<project>` to a
copy of it and you have a one-tap "straight into hausfold" share.

## Migration from the Things-shaped tracker (`tracker migrate`)

Backs `tracker/` up to `~/.cache/tracker/backup-<stamp>.tgz` first, then per
note, idempotent (a v2 note is untouched):

| was | becomes |
|---|---|
| `type: todo` | dropped |
| `type: area` | `type: project` |
| `status: open` + `heading: now` | `when: now` |
| `status: open` + `when: <date>` | `when: <date>` (kept) |
| `status: open`, otherwise | `when: later` |
| `status: someday` | `when: someday` |
| `status: done` + `done:` | `done:` kept, `status` dropped (`when` → `later` if absent) |
| `status: canceled` + `done: d` | `dropped: d` |
| `heading: now\|later` | folded into `when` |
| `heading: <anything else>` | a tag (sanitized, lower) |
| `deadline:` | `due:` |
| `evening:` | dropped |
| `area:` on a folder note | dropped |
| `things:` (the Things 3 import's uuid) | dropped |
| `project:` outside `log/` | dropped |
| `inbox/<note>.md` | `tracker/<note>.md` |
| a folder note's ```` ```base ```` block | `![[tracker.base#Project]]` |
| folder notes `hausfold`, `hausfold CI cut…` / `nas` | `repo: ~/code/workshop` / `repo: ~/code/qnap-mediastack` |

Then `tracker.base`, `types.json` (old keys removed), the plugin.

## Build

```
nix build ~/.config/nix#tracker                        # → result/bin/tracker
nix shell nixpkgs#go nixpkgs#nodejs -c go test ./...   # from pkgs/tracker
```

`go test` runs the plugin's own tests through node; without node on PATH that
one test skips and the rest still run.

`hosts/mbp/apps.nix` puts the package on PATH; `haus rebuild` activates.
