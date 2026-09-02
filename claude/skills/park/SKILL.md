---
name: park
description: >-
  Set the current working tree aside without losing it, as a `wip:` commit on this
  branch — the stash-free "hold this thought". Use when I say /park, "park this",
  "set this aside", "stash this", "shelve it", "I need this tree clean for a
  minute", or when you need a clean tree yourself mid-task (to switch branches,
  test something else, pull). Also covers `/unpark` — putting the parked changes
  back. NEVER use `git stash` in a repo of mine; use this instead.
---

# Park: set work aside as a `wip:` commit, never a stash

`scruff park [label]` commits the whole dirty tree — tracked edits *and* untracked
files — as one `wip:` commit on the branch this checkout has out. `scruff unpark`
rewinds it (`git reset --mixed HEAD^`), putting every file back exactly as it
was, uncommitted.

## Why never `git stash`

The stash stack **looks** per-worktree and isn't. It lives in the shared
`.git` dir, so every agent worktree of a repo *and* the main checkout push and
pop the **same stack**. Two parallel panes stashing means either can pop the
other's entry, and the loser's edits land in a tree that never asked for them —
or vanish into a conflicted mess. A `wip:` commit has no shared stack: it sits
on the branch only this pane has checked out, it survives a pane close, `scruff`
lists it as that worktree's last commit, and `scruff unpark` puts it back.

This holds in the main checkout too, not just worktrees — that's the checkout
most likely to eat someone else's pop.

## /park

1. `scruff park "<label>"` from anywhere inside the checkout. Pass a label whenever
   you know what the work was ("half-done FDA helper") — it becomes the commit
   subject and is what I'll read in `scruff` a week later. Bare `scruff park` is fine
   for a throwaway.
2. Report: how many changes, the short SHA, and the branch.

That's the whole skill when it's a bare `/park`. Don't commit "properly",
don't open a PR, don't push — parking is explicitly *not* landing.

**Refusals to expect, and what they mean:**

- *"nothing to park — `<branch>` is already clean"* — no-op, say so and stop.
- *"HEAD is detached"* — a commit here is reachable from nothing and the next
  checkout orphans it. Check out a branch first (or tell me if that's a
  surprise, because it usually means something else went wrong).
- *"note: `<branch>` isn't an agent branch — don't push this wip commit"* —
  you parked on `main` or a named branch. Fine, but treat that tree as owing me
  an `unpark` soon; **never** push a `wip:` commit on `main`.

## /unpark

`scruff unpark` — only ever undoes the **last** commit, and only if its subject
starts with `wip:`. If HEAD isn't a wip commit it refuses and names what HEAD
actually is; don't work around that by resetting by hand.

**It refuses a pushed wip commit** ("unparking would rewrite published
history"). That's deliberate — a parked commit that reached the remote is
visible in an open PR, so rewinding it locally turns "give me my files back"
into a force-push. Never do that behind my back: report the refusal, and if I
confirm I mean it, the escape hatch it prints is `git reset --mixed HEAD^`.

## Parking as a means, not an end

When you need a clean tree *for your own next step* — switch branches, bisect,
pull, test a sibling change — park first, do the thing, then `scruff unpark` in the
same turn. Say in one line that you did it; don't leave my tree parked and
walk away.

The pane-close hook already parks automatically (`wip: auto-saved on pane
close`), so a worktree you never got to is never lost — `scruff <name>` rebuilds
the checkout and `scruff unpark` restores the tree. `scruff park` is just the on-demand
half of that same mechanism.
