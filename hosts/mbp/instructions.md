# Global instructions

How I (julienmartel) like to work, across every repo and every client.
Repo-specific detail lives in each project's own AGENTS.md, not here.

## How to answer me

Load the `brief` skill at the start of every session and hold its shape all
session, until I say "drop brief". My others are `ship`, `things`, `later`,
`unslop`, `wizard`, `grill`, `conflicts`, `deepen`, `blast-radius` and
`show-me`; a client that does not index skills reads
`~/.agents/skills/<name>/SKILL.md` by path.

Three fire without being invoked. **`unslop`**: any reader-facing copy you
write, you unslop before handing it to me — no em dashes in *copy*, while my
AGENTS.md files are full of them and are RIGHT, so do not "fix" those.
**`wizard`**: three or more steps only I can take get written as a script, not
a chat list. **`later`**: what leaves this session unfinished leaves in
Things, not in your last message — up to three unasked, never on Today.

## Working in a git worktree

Detect it: `git rev-parse --git-common-dir` points outside your toplevel.

- **Commit, push and open the PR without asking** — all three, standing
  permission; unpushed or PR-less is unfinished. Only *merging* waits for me.
- **Build and verify without asking.** Only *activation* (`darwin-rebuild
  switch` and its wrappers) is mine — build, then hand me the verb. Use a
  repo tooling's named override only if I already asked you to activate.
- **Land through a PR** — never a direct push or a local `git merge` into
  `main`, and never touch the main checkout's files. "ship it" / `/ship` IS
  the go-ahead to `gh pr merge`; absent it, stop at "PR open" with the link.
- **Do not sync with main unless a real conflict forces it, and then rebase**
  — `git rebase origin/main`, force-push; never `git merge origin/main`,
  which puts commits I did not write in my PR. `flake.lock` is never
  hand-merged:
  `git checkout origin/main -- flake.lock` (NOT `--theirs`, which in a rebase
  means my own branch), then `nix flake update <input>` only if the branch
  needed a newer pin. Past a lockfile: load `conflicts`.

A plain session on `main` is fine for a small one-off, and committing there
directly is expected.

## How I ship and verify

**Ship by default, sized to the change — in repos I own solo** (the hausfold
family, qnap-mediastack, `~/.config/nix`; a child gitignored under
`~/code/workshop` is still one). Small — bugfix, typo, theme tweak, version
bump, docs — commit, verify and ship in the same turn without asking; a
verified fix left unshipped is a bug, not a finished task. Big or risky:
verify it works, then ask, then drive it to shipped. Releases and user-facing
publishes are always gated. In shared or client repos, prepare the change and
ask before pushing. Unsure? Ask.

**Verify by actually running it**, not by eyeballing the diff; testing in prod
is house style here. Prefer a project's own run/verify skill.

## Command vocabulary

Every command you put in front of me is the family wrapper, never the raw
incantation it wraps: `haus rebuild`, not `nix build` + `darwin-rebuild
switch`. The wrappers carry the guards. Raw `nix`/`git` only where no wrapper
covers the operation, and say so in the same line.

## Do not drive my terminal

Never open or close a Ghostty window for me; ask, or hand me the command. For
a main-checkout-only step, `cd` there and run it in place.

## Memory

Auto-memory is off deliberately (`autoMemoryEnabled = false`, set on every
rebuild by `hosts/mbp/claude-code.nix`). Do not ask for it back on, and keep
no parallel note store: **the code, the git history and each repo's own
AGENTS.md are the source of truth.** Something worth carrying between
sessions goes in the repo it belongs to — a line in AGENTS.md, a comment
beside the code, or a commit message. Account-level memory in the Claude
apps is separate and stays on, for non-code conversations.

## Keeping docs honest

If an AGENTS.md, CLAUDE.md, README or docs file is wrong or stale, fix it in
the same change rather than working around it. Keep those files short and
*current* — what is true now, not how it got that way.
