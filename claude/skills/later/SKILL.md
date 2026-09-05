---
name: later
description: >-
  Put what leaves this session unfinished into my Things 3 list, shaped so a cold
  session can pick it up: a loose end as a to-do, a decided plan as a project of
  demoable slices, an undecided one as a project whose first to-dos are the open
  questions. Use when I say /later, "later", "not now", "another time", "park that
  idea", "add that to my list", "remind me to", "make tickets for this", "write this
  up as a plan", "map this out" — and unasked when a session ends with follow-ups,
  when the plan is bigger than one session, when a grill leaves forks I never
  answered, or when a /ship report has a "next". `/later next [project]` picks the
  next one up. The plumbing is the `things` skill; this is what to file and how.
---

# Later — what leaves the session goes into Things, not into your last message

A follow-up in a wrap-up dies with the pane. Things is the list I actually work from,
so that is where unfinished work goes — but a to-do only counts if a session with no
memory of this one can start it. Everything below serves that one test.

This is my version of aihero.dev's `/to-tickets`, `/to-spec` and `/wayfinder`,
collapsed: one tracker (Things, not GitHub), one question (how settled is it?), and
no spec document — decisions land where `grill` puts them, and the to-do points there.

## One question: how settled is it?

| It is… | Shape | How |
|---|---|---|
| **settled and small** — one to three things, each a session or less | to-dos in the owning project, under its `later` heading where it has one | `things add "<title>" --list <project> --heading later --notes "<brief>" --tags fable` |
| **settled, bigger than a session** | a **project** in area `code`: notes = the brief, to-dos = demoable slices under a `build` heading | `things json` (template below) |
| **not settled** | the same project with a `decide` heading first: one to-do per open fork, in `grill`'s shape. `build` holds only what is already decided | `things json` |

Never build while deciding: a `decide` to-do resolves into an answer, not into code.
The way the upstream skills most often fail is an agent treating a decision as a task.

## What a slice is

Each `build` to-do is a **tracer bullet** — a thin cut through every layer, demoable on
its own — never a layer ("the schema", "the CLI flag", "the tests"). The test: *what do
I see working when this is done?* If the answer is a file, it is not a slice.

- **Title = the demo**, in my voice: `things cancel works on a project`, not
  `add update-project support`. No `path:line` in a title.
- **Checklist = the acceptance**: one to three observable checks, each false today.
- **Order = blocking order.** Things has no edges, so list order is the order, and a
  `Blocked by: <title>` line in the notes names anything that must land first. The
  first to-do has nothing above it and can start now.
- **One session each.** A slice that needs the brief re-read across two panes is two.
- **Prefactoring goes first**, as its own slice. A wide mechanical change (a rename
  across many callers) goes expand → migrate → contract, three slices.

## What goes in the notes

The notes are a **handoff** — `~/.claude/skills/handoff/SKILL.md` has the shape
(Where · State · Verified · Next · Watch out · Read first), 150 words, hard cap 250.
What the to-do already carries in its own fields (title, checklist, tags) stays out.

- **Point, never copy.** An AGENTS.md rule, a PR, a doc, an `ops/todo/*.md` file: the
  path or URL. Two copies drift.
- **Decisions are not notes.** A rule that binds future work goes where `grill` puts
  it — an AGENTS.md stanza, a comment beside the code, the commit message — and the
  notes cite that path. Things is my list, not a second note store.
- **Say what is unproven.** "builds, not feel-tested" beats "done".
- A **`decide`** to-do's notes are `grill`'s four parts: the fork in one sentence, the
  one fact that makes it real, A) and B), your pick and the reversal cost.

A **project's** notes are the brief for the whole effort: **Destination** (one
sentence), **Decided** (one line each, past tense, with where it was written), **Out
of scope** (what was ruled out, so nobody re-opens it), **Not yet specified** (the fog:
what you know is coming but cannot phrase as a fork yet).

### `things json` template

```json
[{"type":"project","attributes":{"title":"<effort>","area":"code","notes":"<brief>","items":[
  {"type":"heading","attributes":{"title":"decide"}},
  {"type":"to-do","attributes":{"title":"<the fork>","notes":"<grill shape>","tags":["fable"]}},
  {"type":"heading","attributes":{"title":"build"}},
  {"type":"to-do","attributes":{"title":"<the demo>","notes":"<handoff>","tags":["fable"],
    "checklist-items":[{"type":"checklist-item","attributes":{"title":"<observable check>"}}]}}
]}}]
```

A to-do falls under the heading above it. Drop the `decide` pair when there is nothing
to decide. `DRY_RUN=1 things json '<array>'` prints the URL instead of firing it.

## Where it lands

- **The owning project**, by repo: `things projects` lists them (`hausfold` for the
  family, `nas` for the NAS…). A plan or a map is its own project in area `code`,
  named for the effort — the standing `hausfold` project is for loose ends, not plans.
- **No match → Inbox.** Never Today, never a `when` or a deadline, unless I said now.
  Today is the list I live in; nothing lands on it uninvited.
- **Tag `fable`** on anything an agent can take cold — that is what the tag means on my
  existing items. `things tags` if it has moved.
- **`ops/todo/` already has the plan?** One to-do pointing at the file, not the plan
  twice.

## How much, unasked

| Trigger | You |
|---|---|
| my words — "later", "not now", "remind me", "add that", `/later` | file it now, in the same turn |
| you noticed it — a loose end at the end of a session, a fork I never answered | file up to **three**, print each with its id so one `things cancel <id>` undoes it |
| more than three, or a whole plan | list them, ask which. A project I have not seen does not get created |

Never invent, never tidy, never reschedule what is already there (`things` house
rules). Before filing, `things search "<key words>"` — if I already have it, append to
that one (`things update <id> --append-notes "…"`) instead of adding a twin.

Writes are async: `things show "<title>"` to confirm, then quote the id in your report.

## `/later next [project]` — picking one up

The reverse direction, so the list is a frontier and not a graveyard.

1. `things list <project> --json` (default `hausfold`). The candidate is the first open
   to-do under `decide`, else the first under `build` or `now` tagged `fable`.
2. Print its title and notes. Nothing else until I say go.
3. A **`decide`** to-do: grill it, here — one fork, two options, your pick. Write the
   answer where `grill` says, append one line to the to-do
   (`things update <id> --append-notes "→ <answer> · <where written>"`), then
   `things complete <id>`. The project's *Decided* list is its completed `decide` to-dos.
4. A **`build`** to-do: its notes are already the prompt. Write them to a file with two
   lines appended — `things: <id>` and `On /ship: things complete <id>` — and spawn it
   the way `handoff`'s lane ending does:
   ```sh
   scruff spawn <repo main checkout> <name> --prompt-file <file>
   things update <id> --append-notes "lane: <repo>/<name>"
   ```
   The lane completes the to-do when its PR lands; nothing else does.

## Two things it never does

- **Write a spec document.** No `SPEC.md`, no `docs/plan.md`, no `.scratch/`. The
  project's notes are the map; the decisions live where `grill` puts them.
- **Touch the screen.** Every write goes `open -g` through `things`; never `--reveal`.
