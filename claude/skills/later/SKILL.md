---
name: later
description: >-
  Put what leaves this session unfinished into my tracker, shaped so a cold
  session can pick it up: a loose end as a to-do, a decided plan as a project of
  demoable slices, an undecided one as a project whose first to-dos are the open
  questions. Use when I say /later, "later", "not now", "another time", "park that
  idea", "add that to my list", "remind me to", "make tickets for this", "write this
  up as a plan", "map this out" — and unasked when a session ends with follow-ups,
  when the plan is bigger than one session, when a grill leaves forks I never
  answered, or when a /ship report has a "next". `/later next [project]` picks the
  next one up. The plumbing is the `tracker` skill; this is what to file and how.
---

# Later — what leaves the session goes into the tracker, not into your last message

A follow-up in a wrap-up dies with the pane. The tracker is the list I actually work
from, so that is where unfinished work goes — but a to-do only counts if a session with
no memory of this one can start it. Everything below serves that one test.

This is my version of aihero.dev's `/to-tickets`, `/to-spec` and `/wayfinder`,
collapsed: one tracker (markdown in my vault, not GitHub), one question (how settled is
it?), and no spec document — decisions land where `grill` puts them, and the to-do
points there.

## One question: how settled is it?

| It is… | Shape | How |
|---|---|---|
| **settled and small** — one to three things, each a session or less | to-dos in the owning project, `later` (the default) | `tracker add "<title>" --in <project> --notes "<brief>" --tags fable` |
| **settled, bigger than a session** | a **project** under `code`: notes = the brief, to-dos = demoable slices tagged `build` | `tracker project add` + `tracker add … --tags fable,build` (recipe below) |
| **not settled** | the same project with `decide` to-dos first: one per open fork, in `grill`'s shape. `build` holds only what is already decided | same, `--tags fable,decide` for the forks |

Never build while deciding: a `decide` to-do resolves into an answer, not into code.
The way the upstream skills most often fail is an agent treating a decision as a task.

## What a slice is

Each `build` to-do is a **tracer bullet** — a thin cut through every layer, demoable on
its own — never a layer ("the schema", "the CLI flag", "the tests"). The test: *what do
I see working when this is done?* If the answer is a file, it is not a slice.

- **Title = the demo**, in my voice: `tracker drop works on a project`, not
  `add update-project support`. No `path:line` in a title. The title is the file name,
  so `/ : # [ ] |` fall out of it — `tracker` keeps the exact wording in `title:`.
- **Checklist = the acceptance**: one to three observable checks, each false today.
- **Order = blocking order.** The tracker has no edges and sorts by name, so a
  `Blocked by: <title>` line in the notes names anything that must land first. The
  first slice has no such line and can start now.
- **One session each.** A slice that needs the brief re-read across two panes is two.
- **Prefactoring goes first**, as its own slice. A wide mechanical change (a rename
  across many callers) goes expand → migrate → contract, three slices.

## What goes in the notes

The notes are a **handoff** — `~/.claude/skills/handoff/SKILL.md` has the shape
(Where · State · Verified · Next · Watch out · Read first), 150 words, hard cap 250.
What the to-do already carries in its own fields (title, checklist, tags) stays out.
`tracker spawn` turns exactly those notes into the lane's prompt, so write them as the
prompt you would want to receive.

- **Point, never copy.** An AGENTS.md rule, a PR, a doc, an `ops/todo/*.md` file: the
  path or URL. Two copies drift.
- **Decisions are not notes.** A rule that binds future work goes where `grill` puts
  it — an AGENTS.md stanza, a comment beside the code, the commit message — and the
  notes cite that path. The tracker is my list, not a second note store.
- **Say what is unproven.** "builds, not feel-tested" beats "done".
- A **`decide`** to-do's notes are `grill`'s four parts: the fork in one sentence, the
  one fact that makes it real, A) and B), your pick and the reversal cost.

A **project's** notes are the brief for the whole effort: **Destination** (one
sentence), **Decided** (one line each, past tense, with where it was written), **Out
of scope** (what was ruled out, so nobody re-opens it), **Not yet specified** (the fog:
what you know is coming but cannot phrase as a fork yet). They live in the folder note
(`tracker/<effort>/<effort>.md`), above the embedded Project view. Give it a `repo:`
(`--repo`) so `tracker spawn` knows where its slices run.

### Recipe for a project

```bash
tracker project add "<effort>" --in code --repo ~/code/workshop --notes "<brief>"
tracker add "<the fork>" --in "<effort>" --tags fable,decide --notes "<grill shape>"
tracker add "<the demo>" --in "<effort>" --tags fable,build  --notes "<handoff>" \
            --checklist '<observable check>|<observable check>'
```

Drop the `decide` line when there is nothing to decide. `tracker add --dry-run …`
prints the note instead of writing it.

## Where it lands

- **The owning project**, by repo: `tracker projects` lists them (`hausfold` for the
  family, `nas` for the NAS…). A plan or a map is its own project under `code`,
  named for the effort — the standing `hausfold` project is for loose ends, not plans.
- **No match → `--in` omitted → unfiled.** Never `--now`, never a `--due`, unless I
  said now. Today is the list I live in; nothing lands on it uninvited. `later` is the
  default and needs no flag.
- **Tag `fable`** on anything an agent can take cold — that is what the tag means on my
  existing items.
- **`ops/todo/` already has the plan?** One to-do pointing at the file, not the plan
  twice.

## How much, unasked

| Trigger | You |
|---|---|
| my words — "later", "not now", "remind me", "add that", `/later` | file it now, in the same turn |
| you noticed it — a loose end at the end of a session, a fork I never answered | file up to **three**, print each with its id and `file://` link so one `tracker drop "<id>"` undoes it |
| more than three, or a whole plan | list them, ask which. A project I have not seen does not get created |

Never invent, never tidy, never reschedule what is already there (`tracker` house
rules). Before filing, `tracker search "<key words>"` — if I already have it, append to
that one (`tracker note "<id>" "…"`) instead of adding a twin.

Every write ends with the id and the `file://` line the verb prints; that link is the
one I can click in a pane.

## `/later next [project]` — picking one up

The reverse direction, so the list is a frontier and not a graveyard.

1. `tracker list <project> --json` (default `hausfold`). The candidate is the first open
   to-do tagged `decide`, else the first tagged `build` or in `now` tagged `fable`.
2. Print its title and notes. Nothing else until I say go.
3. A **`decide`** to-do: grill it, here — one fork, two options, your pick. Write the
   answer where `grill` says, append one line to the to-do
   (`tracker note "<id>" "→ <answer> · <where written>"`), then
   `tracker done "<id>"`. The project's *Decided* list is its closed `decide` to-dos.
4. A **`build`** to-do: `tracker spawn "<id>"`. It writes the prompt from the note
   with `tracker: <id>` and `On /ship: tracker done "<id>"` appended, spawns the lane
   in the background on the project's `repo:`, marks the to-do `now` and stamps
   `lane:`. The lane completes the to-do when its PR lands; nothing else does.

## Two things it never does

- **Write a spec document.** No `SPEC.md`, no `docs/plan.md`, no `.scratch/`. The
  project's folder note is the map; the decisions live where `grill` puts them.
- **Touch the screen.** Every write is a file edit through `tracker`; never `open`,
  never the `obsidian` CLI. `tracker spawn` is a background lane and a banner.
