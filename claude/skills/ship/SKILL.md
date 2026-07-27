---
name: ship
description: >-
  Finish the current piece of work and land it: commit stragglers, open a PR, merge it,
  clean up every worktree the session spun up, then report and stop. Use when I say /ship,
  "ship it", "I'm done with this", "merge and clean up", or want to wrap up a feature branch
  / worktree. Never opens or closes a zellij pane. This is the GENERIC fallback —
  if the current repo defines its own ship skill (deploy steps, ripple, etc.), that one is
  scoped to the repo and wins; use it instead of this.
---

# Ship (generic): PR → merge → clean up → report

End-state: the work is merged into `origin/<main>` **through a PR**, every worktree this
session created (except the one I'm in) is reaped, and you've reported + stopped. `/ship`
never opens or closes a zellij pane — I manage panes myself. Don't stop halfway *before*
that end-state, though.

## First: is there a repo-specific ship?

If this repo has its own `.claude/skills/ship/SKILL.md`, Claude Code surfaces that one
(scoped skills win) — follow it, not this. This generic flow is for repos with no ship
skill of their own, and assumes I own the repo solo. **In a shared or client repo:** open
the PR but stop before merging, and ask first (per my global CLAUDE.md).

## Why a PR, and why /ship merges it

Landing through a PR (never a direct push or a local `git merge` into `<main>`) is what
keeps parallel agents from clobbering each other — a PR is atomic and conflict-detected.
"Merging is my call" means *don't merge unprompted*. **Invoking /ship IS that prompt:**
you've been told to land this, so open the PR for the safety, then merge it yourself.

## Steps

1. **Commit stragglers.** `git status` — commit uncommitted changes that belong to this
   work. If it's unclear whether a file belongs, ask; don't sweep unrelated changes in.

2. **Verify it works** however this repo is verified — run it, tests, build. Don't land a
   broken change.

3. **Determine the main branch.** `git symbolic-ref refs/remotes/origin/HEAD` (or `main`
   vs `master`). Use that as `<main>`.

4. **Push + open the PR.**
   ```bash
   git push -u origin HEAD
   gh pr create --base <main> --fill      # real title/body when it helps
   ```

5. **Merge the PR** (solo repo only — shared/client: stop here and let me merge):
   ```bash
   gh pr merge --squash --delete-branch
   ```
   If it's not mergeable (conflicts / non-fast-forward): `git fetch origin && git rebase
   origin/<main>`, push, retry. On conflicts you can't cleanly resolve, **stop and show
   them** — never force-push `<main>`. On the current worktree's own branch the *local*
   branch delete may be skipped because you're standing on it — that's fine, the `wt`
   remove hook reaps the merged branch when the pane closes.

6. **Clean up every worktree this session spun up** — in this repo or any other. A session
   often hand-creates a *sibling* worktree (`git worktree add`) to do work that belongs in
   another repo; those are NOT auto-reaped. For each one you created: make sure its branch
   is merged (open + merge its PR the same way), then remove it:
   ```bash
   git -C <that-repo> worktree remove <path>     # --force only if you've confirmed it's clean
   ```
   `wt` (if on PATH) lists every agent worktree across all repos — use it to catch any you
   forgot. Don't delete worktrees you didn't create.

7. **Move the local `<main>` ref** so my next worktree forks from what just shipped:
   ```bash
   git fetch origin <main>:<main>
   ```
   Safe even if the main checkout is dirty on another branch; it only refuses if `<main>`
   is checked out somewhere (then ff-pull that checkout if clean, else leave it and say
   so). Never touch the main checkout's working files.

8. **Report, land the verify-list, then settle-or-surface.** Print the report *first* —
   closing the pane wipes it from screen: the `<main>` SHA, what you verified, which PRs
   merged, which worktrees you removed.

   Then, **always as the last thing in the thread** (so it survives a pane close and is my
   test checklist), a bottom-anchored verify-list — every PR this session opened (often more
   than one), oldest first:

   ```
   ## 🧪 To verify — merged, not released. Break something? Fresh agent + the link + what broke.

   - [repo#35](https://github.com/owner/repo/pull/35) — <one line: what changed> · **check:** <1–3 concrete, observable steps>
   ```

   Each entry is a `[repo#N](url)` markdown link — repo-qualified, never the word "PR", the
   link is the highlight. Test steps are concrete and observable, never "confirm it works."
   Then **open every PR URL in Chrome** via the browser tools if they're loadable (ToolSearch
   them first); skip silently in a headless/cron ship — the block above is the reliable copy.

   Now judge whether anything deserves my attention:
   - **Something ≥ ~3/5 importance** — an unexpected result, a decision I need to make, a
     failure, a risky change that wants a look — **surface it and stop.**
   - **Only low-importance notes (≤ 2.5/5) and it's all settled — report and stop.** Leave
     the pane exactly where it is: I open and close my own panes. Don't spawn a pane, don't
     close this one. The current worktree isn't reaped here (you're still sitting in it) —
     it's cleaned up when I close the pane myself (the `wt` remove hook) or by a later
     `wt reap`. Don't wait on CI unless CI is what this thread was about.
