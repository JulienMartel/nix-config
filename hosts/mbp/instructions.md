# Global instructions

How I (julienmartel) like to work, across every repo and every client.
Repo-specific detail lives in each project's own AGENTS.md, not here.

## How to answer me

Load the `brief` skill at the start of every session and hold its shape all
session: verdict first, at most 5 anchored steps, and escalate to me only at
3/5 or above, with a recommendation and a reversal cost. It governs code
work, research and anything I paste. "drop brief" / "full mode" turns it off.
The body is `~/.config/nix/claude/skills/brief/SKILL.md`, linked
OUT-of-store into both `~/.claude/skills/brief` and `~/.agents/skills/brief`
(Codex and OpenCode read the second), so editing it is live in the next
pane with no rebuild. Same for `ship`, `park` and `things` (my Things 3
to-dos — read its SKILL.md before touching my list), `later`, `unslop`,
`wizard`, `grill`, `conflicts`, `deepen` and `blast-radius`. If your
client does not load skills, read the SKILL.md by path; it is plain
markdown.

Three of those carry a standing rule rather than waiting to be invoked:

- **`unslop` — any reader-facing copy you write, you unslop before you hand
  it to me.** Docs, landing pages, READMEs, release notes, App Store text,
  an issue or PR body, an email. Not a favour I ask each time. The scoping
  is the whole skill: no em dashes in *copy*, while my AGENTS.md files are
  full of them and are RIGHT — do not "fix" those. Run
  `claude/skills/unslop/unslop-scan` for the mechanical half.
- **`wizard` — three or more steps only I can take, and you write me a
  script instead of a chat list.** A key you cannot mint, a dashboard you
  cannot click, an ordered gate. You write it, I run it: my secrets stay out
  of your context and nothing takes the screen. One or two steps stay in
  `brief`'s **Need from you** block.
- **`later` — what leaves this session unfinished leaves in Things, not in
  your last message.** When I say later / not now / remind me / add that to
  my list, when a session ends with a loose end, when the plan is bigger
  than one session, when a grill leaves a fork I never answered. Shaped so
  a cold session can start it (`/later next` is the pickup): a to-do under
  the owning project's `later` heading, or a project of demoable slices in
  the `code` area when it is a whole plan. Up to three unasked, never on
  Today, never a spec document. `things` is the plumbing; `later` says what
  to file and how.

`grill` is invoked, not standing: before a change big enough that guessing
wrong costs a rebuild, read the code and the real docs first, then ask me
the ≥3/5 forks one at a time, each with your pick. Answers land in an
AGENTS.md stanza, a comment beside the code, or the commit message —
never a new note store, per **Memory** below.

`blast-radius` is invoked too: for "what could this break" or a diff I
don't trust, find the one fact the change is safe because of and prove it
by running real code — a safety fact you can't prove is reported as
unproven, never written up as settled.

`/handoff` ships with scruff, not this repo (`ai/handoff/SKILL.md` in
hausfold/scruff). It writes a brief a cold session can act on: `/handoff`
copies it to the clipboard, `/handoff spawn [repo]` opens it as a real lane
with its own checkout, branch and window. Edit it there.

## Working in a git worktree

Detect it: `git rev-parse --git-common-dir` points outside your toplevel.
When it does:

- **Commit, push and open the PR without asking.** Standing permission, all
  three. The only step that waits for me is *merging*. A verified change
  left uncommitted, unpushed or without a PR is an unfinished task.
- **Build and verify without asking.** A build is read-only toward every
  checkout, a child repo's included, so it is exactly what a worktree is for
  — do not stop at "the diff is ready". Only *activation* (`darwin-rebuild
  switch` and its wrappers) is mine: it is machine-wide and serial, so five
  parallel agents each with a good reason to switch would silently overwrite
  one another. Build, then hand me the exact command. Where a repo's tooling
  enforces this it names its own override in the refusal — use that if I
  have already asked you to activate, rather than asking again.
- **Running a repo's push/ship step is fine** — it only pushes commits that
  already exist and never activates.
- **Land through a PR — never a direct push or a local `git merge` into
  `main`,** and never touch the main checkout's files. Parallel agents
  pushing straight to main have clobbered each other; a PR is
  conflict-detected and atomic. Merging is my call, which means do not merge
  *unprompted*, not "never merge": when I say `/ship`, "ship it" or "merge
  and clean up", that IS the go-ahead — `gh pr merge`, still never a local
  merge. Absent that, stop at "PR open" and give me the link.
- **Do not sync with main unless a real conflict forces it, and then
  rebase.** GitHub merges a PR that is merely behind. `git rebase
  origin/main`, then force-push: my `worktree-*` branches are single-agent
  and nobody bases on them, so rewriting them is free. Never `git merge
  origin/main` into a branch — it puts commits I did not write in my PR's
  commit list. `flake.lock` is never hand-merged: take main's wholesale
  (`git checkout origin/main -- flake.lock` — NOT `--theirs`, which means
  main in a merge but my own branch in a rebase, and rebase is what I run),
  then re-run `nix flake update <input>` if the branch genuinely needed a
  newer pin (raw on purpose — no wrapper covers a branch-local repin; `bench
  ship` works on main checkouts). Anything past a lockfile: load the
  `conflicts` skill, which triages generated files and resolves the rest by
  reading why each side exists.
- **`/ship` finishes the whole job**: merge the PR, then clean up every
  worktree this session spun up — a sibling-repo worktree is not
  auto-reaped, so merge its PR too and `git worktree remove` it. Then report
  and stop. It does not close this pane or open one. The current worktree is
  not reaped (you are still in it); it goes when I close the pane.

A plain non-worktree session on `main` is fine for a small one-off, and
committing to main directly is expected there. The PR rule exists to stop
*parallel* agents clobbering each other.

## How I ship

**Ship by default, sized to the change — in repos I own solo** (my personal
infra: the hausfold family, qnap-mediastack, `~/.config/nix`). In shared or
client repos, prepare the change and ask before pushing.

- **Small** (bugfix, typo, config/theme tweak, version bump, docs): commit,
  verify and ship in the same turn without asking. A verified fix left
  unshipped is a bug, not a finished task.
- **Big or risky** (new feature, refactor, anything hard to roll back,
  anything a user could feel break): verify it works, then ask. Once
  approved, drive it all the way to shipped.
- **Releases and user-facing publishes are always gated.** Propose one after
  shipping user-facing changes; never tag or publish unprompted.
- Unsure which bucket? Ask.

## Repos nested inside other repos

The hausfold family (`nebelung`, `pounce`, `haus`, …) sits under
`~/code/workshop`, whose `.gitignore` lists each child. **That nesting only
keeps the outer tree clean; each child is a full, independent repo I own
solo.** `cd` into it and commit / push / ship it under its own rules and the
policy above — a child being gitignored by the parent says nothing about
committing inside it, and is not a signal that git ops there are risky. When
I ask for a cross-repo flow, run it end to end, landing each branch by
merging its PR, without re-confirming each repo word for word.

## Do not drive my terminal

Do not open or close Ghostty windows for me. If a task genuinely needs one,
ask first or hand me the command. To do a main-checkout-only thing from a
worktree (activating after a ship), `cd` to the main checkout and run it in
place rather than spawning a window to carry it.

## How I verify

**Verify by actually running it**, not by eyeballing the diff. Testing in
prod is acceptable house style for my personal infra: build it, run it,
observe the real behavior. Prefer a project's own run/verify skill.

## Command vocabulary — hand me verbs, never the raw incantation

Every command you put in front of me — a step, a "Need from you" block, a
wrap-up — is the family wrapper, never the raw command it wraps: the lock
ripple is `bench ship` (or `bench ship <repo>` for one repo's downstream),
never `nix flake update <input>` + commit per repo; this machine's update
is `haus update` and its rebuild `haus rebuild`, never a `nix build` +
`darwin-rebuild switch` pipeline; rollback is `haus rollback`; catching
checkouts up is `bench pull`; setting work aside is `scruff park`, never
`git stash`. The wrappers carry the guards (ship's
fast-forward-then-verify, rebuild's build-before-switch) — a raw
suggestion sheds them and teaches the wrong habit, even when it would
work. Raw `nix`/`git` is right only when no wrapper covers the operation;
say "no wrapper for this" when so. On a haus machine that is not mine (an
end user, no workshop checkout), the `haus` CLI is the whole vocabulary —
a step it cannot express is a missing verb to report to me as a gap, never
a nix command to hand the user.

## Memory

Auto-memory is off, deliberately: `autoMemoryEnabled = false` in
`~/.claude/settings.json`, set on every rebuild by `hosts/mbp/default.nix`.
**The code, the git history and each repo's own AGENTS.md are the source of
truth for code work.** Do not ask for it back on, and do not keep a parallel
note store anywhere else. Something worth carrying between sessions goes in
the repo it belongs to: a line in AGENTS.md, a comment beside the code that
embodies it, or a commit message. If it fits none of those, it was probably
not worth keeping.

Account-level memory in the Claude apps (iOS, web chat) is a separate
setting and stays on. That is for non-code conversations, not this.

## Keeping docs honest

If something in an AGENTS.md, CLAUDE.md, README or docs file is wrong or
stale, fix it in the same change rather than working around it. Keep those
files short and *current* — state what is true now, not how it got that way.
Push detail into the matching docs file rather than growing the top-level
one.
