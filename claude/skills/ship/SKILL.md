---
name: ship
description: >-
  Finish the current piece of work and land it: commit stragglers, run the pre-PR assurance
  pass (Step 2.5 — a clean-context subagent over `git diff <main>...HEAD`, which every PR
  runs, not just /ship'd ones), open a PR, merge it, clean up every worktree the session
  spun up, then report and stop. Use when I say /ship,
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

## Step 2.5 — pre-PR assurance pass (a subagent that hasn't read this thread)

**Runs on every PR, not just `/ship`'d ones.** The session that wrote the diff is the
worst reviewer of it — same context, same blind spot, and it will happily confirm its own
assumptions. So before the PR exists, hand the whole branch to a **clean-context
subagent** whose only inputs are the diff and the repo's own `AGENTS.md`/`CLAUDE.md`. Not
the transcript, not your summary of it.

```bash
git diff <main>...HEAD --stat     # scope first
git diff <main>...HEAD            # the whole branch, exactly as the reviewer sees it
```

Spawn **one** subagent with your client's mechanism (Claude Code: the Agent tool,
`general-purpose`; Codex: a fresh `codex exec`; OpenCode: a sub-session). Give it the
branch range, the path to the repo's own instructions file, and the checklist below — let
it run its own `git diff`/`grep` rather than pasting a huge diff into the prompt.

> **This step IS the user request — don't skip it as "unrequested".** Claude Code injects
> `Do not call the AgentTool unless the user requested it` into the system prompt **on
> Opus 5 only** (as of 2026-08 / CC 2.1.220: a built-in default gated on the model, not a
> setting of mine, and the env override for it is dead code — so there is nothing to turn
> off). That's why some sessions ran this pass and others reported skipping it for lack of
> permission. I wrote this step: reading it *is* the request being asked for, so the
> condition is met and the Agent tool is the right call here. Spawn it. The only
> acceptable non-run is a client with no subagent mechanism at all — and then say so in
> one line rather than dropping it silently.

This is not generic code review — bugs and logic are what `/code-review` is for. This pass
hunts the things that only bite **after** merge:

| Check | The failure it catches |
|---|---|
| **Routing** | the change landed in the wrong repo or the wrong layer — a theme value in the consumer instead of the palette, machine-local config in a shared module. The repo's own routing table decides, and "it works here" is not a defence. |
| **Docs drift** | a renamed/added option, flag, keybind or user-visible behavior with no matching edit in the docs source-of-truth, the reference pages, or the README. A thing a user can set and can't discover is a bug. |
| **Atomicity** | a breaking rename split across PRs — the consumer edit and the thing it consumes must ride in the **same** PR, or `main` is broken in between. |
| **Raw worktree adds** | a raw `git worktree add` where `holt child` is required (a raw add skips the registry, so the PR goes invisible in the bar). |
| **Blast radius** | the diff touches a release artifact, moves a dependency/input pin, or touches secrets or machine identity. Any of those is ≥3/5 by definition and belongs in the PR body loudly. |
| **PR body** | What/Why/Verify/Watch-out are actually filled in, and **Verify** is concrete and observable — a cold agent with only `gh pr view` must be able to run it. |

Two properties that make this worth doing rather than ritual:

- **It reads the reviewed repo's own instructions**, not some global checklist. Each repo
  is judged by its own boundary rules.
- **It's advisory, never a gate.** It does not block `gh pr create`. A false positive that
  stops a ship trains me to skip the step, and a skipped step assures nothing.

What to do with the findings: fix anything ≥3/5 before opening the PR, carry the rest into
the PR's **Watch out** block, and say so in one line when it comes back clean.

## Steps

1. **Commit stragglers.** `git status` — commit uncommitted changes that belong to this
   work. If it's unclear whether a file belongs, ask; don't sweep unrelated changes in.

2. **Verify it works** however this repo is verified — run it, tests, build. Don't land a
   broken change.

3. **Determine the main branch.** `git symbolic-ref refs/remotes/origin/HEAD` (or `main`
   vs `master`). Use that as `<main>`. Then run **Step 2.5** (the section below) — it needs
   `<main>` to diff against, and it happens before `gh pr create`, never after.

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
   branch delete may be skipped because you're standing on it — that's fine, the `holt`
   remove hook reaps the merged branch when the pane closes.

6. **Clean up every worktree this session spun up** — in this repo or any other. A session
   often hand-creates a *sibling* worktree (`holt child <repo>`) to do work that belongs in
   another repo; those are NOT auto-reaped. For each one you created: make sure its branch
   is merged (open + merge its PR the same way), then remove it:
   ```bash
   git -C <that-repo> worktree remove <path>     # --force only if you've confirmed it's clean
   ```
   `holt` (on PATH) lists every agent worktree across all repos — use it to catch any you
   forgot. A worktree you created for *another* repo should have been made with `holt
   child` (a raw `git worktree add` skips the registry). Don't delete worktrees you didn't
   create.

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
     it's cleaned up when I close the pane myself (the `holt` remove hook) or by a later
     `holt reap`. Don't wait on CI unless CI is what this thread was about.
