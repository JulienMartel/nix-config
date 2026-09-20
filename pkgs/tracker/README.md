# tracker

My to-do list: one markdown note per to-do in the Obsidian `notes` vault
(iCloud, so the phone has it), one folder per project, Obsidian Bases for the
views, one Go binary for the shell — a CLI for agents and scripts, a fullscreen
TUI for me. Two pounce commands and a tiny Obsidian plugin sit on top of the
CLI. Nothing here is a Things 3 clone: the base is four properties, and
everything else (areas, boards, the logbook, lanes) falls out of Obsidian doing
what it already does.

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
    └── log/                    # the archive: closed notes `tracker archive` moved out of the way
```

## The base: a to-do

```yaml
---
when: later          # REQUIRED · now | later | someday | YYYY-MM-DD
due: 2026-09-30      # optional · a hard deadline
done: 2026-09-20     # set = closed on that day   (dropped: 2026-09-20 = abandoned instead)
tags: [fable]        # optional · #fable = an agent can take it cold · #decide / #build = the kind of work
created: 2026-09-20
---
The notes. `- [ ]` lines are the checklist. Images the way Obsidian pastes them.
```

- **`when`** is the one field that matters and it is never empty: `now` (on
  Today), `later` (the default), `someday` (parked), or a date — *later until
  that day, then now*. The CLI turns an arrived date into `now` on every read,
  and the Bases Today view catches one the phone reached first.
- **Closed is a date, not a status.** `done:` or `dropped:` set means closed;
  the note stays where it is. Nothing moves on completion, so the phone can
  close a to-do completely with one property. `tracker archive` sweeps closed
  notes older than 30 days into `log/` (stamping `project:` so history keeps
  its list), and the Done view is by `done`, wherever the file sits.
- **No project = the root of `tracker/`.** A folder is a project; its folder
  note (`<folder>/<folder>.md`) carries `type: project`, the brief, an optional
  `repo:` (what `tracker spawn` spawns on), and embeds the Project view. A
  folder inside a folder is a sub-project; a folder of folders is an area. No
  `area` type, no `heading`, no `status`, no `evening`.
- **Optional extras**, all written by verbs: `title:` when the file name had to
  be sanitized, `lane: <repo>/<name>` once `tracker spawn` ran, `repo:` on a
  to-do to override its project's, `project:` only on archived notes,
  `things:` on notes imported from Things 3 (history; never written again).

An **id** is the path under `tracker/` without `.md`: `hausfold/ship the
thing`, or `buy cat food` for an unfiled one. Every verb that takes one also
takes a unique case-insensitive substring of an open item's id or title;
ambiguity prints the candidates and exits 1.

### Which notes are to-dos

Every `.md` under `tracker/` except folder notes (`type: project`, or the
note named after its folder). `log/` notes are to-dos too, closed. A note
with no `when` — made by hand in Obsidian — is `later`.

## Views (`tracker.base`)

`tracker init` writes it; `--force` restores the shipped one. Property types
(`due`, `done`, `dropped`, `created` as dates; `when` as text) go in
`.obsidian/types.json`. Views: **Today** · **Later** (grouped by project) ·
**Upcoming** (dated) · **Someday** · **Due** · **Inbox** (unfiled) · **Done** ·
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
                    [--due <date>] [--tags a,b] [--notes <text>] [--checklist 'a|b'] [--edit]
tracker now | later | someday <id>          tracker when <id> <now|later|someday|date>
tracker due <id> <date|none>                tracker done <id> · drop <id> · reopen <id>
tracker move <id> <project|inbox>           tracker rename <id> <title>
tracker tag <id> +a -b                      tracker note <id> <text>       (append)
tracker edit <id>                           ($EDITOR, then re-read)
tracker update <id> [--when …] [--due …] [--tags …] [--add-tags …] [--in …] [--title …] [--append-notes …]
tracker project add <name> [--in <parent>] [--repo <path>] [--notes <brief>] [--todos 'a|b']
tracker project set <name> repo=<path>      tracker promote <id>            (to-do → project folder)
tracker spawn <id> [--repo <path>] [--follow] [--again]   # a lane for this to-do, background, banner when live
tracker archive [--older 30] [--dry-run]    tracker migrate [--dry-run]     tracker init [--force]
```

Aliases kept for the skills: `complete`→`done`, `cancel`→`drop`, `anytime`→`later`,
`add-project`→`project add`, `--project`→`--in`, `--deadline`→`--due`.

- `--json` on any read → `[{id, title, folder, project, when, bucket, due, done,
  dropped, tags, created, lane, repo, path}]`. `bucket` is `now` · `scheduled`
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
project to set it on. Writes the prompt — title, the body, then `tracker: <id>`
and `On /ship: tracker done "<id>"` — and runs it the way haus's Spawn Agent
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
- Keys: `j/k ↑↓` move · `h/l ←→ tab` pane · `⏎` open in the note pane ·
  `a` add (a one-line box; `⇥` cycles now/later/someday, `⌃d` sets due) ·
  `x`/`space` done · `X` drop · `R` reopen · `n` `l` `s` now/later/someday ·
  `w` when (date) · `d` due · `m` move (fuzzy project picker) · `t` tags · `r` rename ·
  `S` spawn lane · `e` `$EDITOR` · `o` open in Obsidian (my key, my screen) ·
  `u` undo last write · `/` filter · `g`/`G` · `A` archive · `?` help · `q`.
- The vault is watched (fsnotify): a change from Obsidian or the phone repaints
  within a second. Writes go through the same code the CLI uses.

## Pounce

`hosts/mbp/pounce/commands/` (out-of-store symlinks into
`~/.config/pounce/commands`, live-edited):

- **Add To-do** (`todo-add.sh`, leader + `a`, palette "todo"): one box —
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
`?add=<title>` protocol the ⚡ column and pounce use. Mobile gets the commands,
not spawn.

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
| `project:` outside `log/` | dropped |
| `inbox/<note>.md` | `tracker/<note>.md` |
| a folder note's ```` ```base ```` block | `![[tracker.base#Project]]` |
| folder notes `hausfold`, `hausfold CI cut…` / `nas` | `repo: ~/code/workshop` / `repo: ~/code/qnap-mediastack` |

Then `tracker.base`, `types.json` (old keys removed), the plugin.

## Build

```
nix build ~/.config/nix#tracker            # → result/bin/tracker
nix shell nixpkgs#go -c go test ./...      # from pkgs/tracker
```

`hosts/mbp/apps.nix` puts the package on PATH; `haus rebuild` activates.
