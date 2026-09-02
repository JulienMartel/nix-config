---
name: conflicts
description: >-
  Finish a merge or rebase that git stopped on — triage the conflicted files, resolve the
  real hunks by reading why each side exists, run the repo's checks, and land it. Use when
  I say /conflicts, "fix the conflicts", "resolve this merge", "the rebase is stuck", "the
  PR won't merge", or when git has already halted with markers in the tree. Never aborts,
  never stashes.
---

# Conflicts — resolve by intent, not by text

Git stops when it can't tell which change was meant. `--ours`, `--theirs` and deleting
markers all make that stop go away without answering it: the markers vanish, the code
compiles, and somebody's intentional change is silently gone. **You cannot preserve an
intent you haven't read.** So this skill spends its first move in the history, not the
diff.

Two rules before anything else:

- **Never `--abort`.** It throws away the resolution work and hands the same conflict back
  next time. Whether to do the merge at all is a decision that belongs *before* you're
  here. If I've changed my mind, I'll say so.
- **Never `git stash`.** The stash stack is shared across every worktree of a repo, so a
  parallel agent can pop yours. Need a clean tree? `scruff park`, then `scruff unpark`.

## 1. Know where you are

```bash
git status                       # says MERGING, REBASING or CHERRY-PICKING
git diff --name-only --diff-filter=U
```

🚨 **`--ours` and `--theirs` are inverted between merge and rebase.** Verified, not
folklore:

| | `--ours` | `--theirs` |
|---|---|---|
| `git merge origin/main` | your branch | **main** |
| `git rebase origin/main` | **main** | your branch |

A rebase checks main out and replays your commits onto it, so "ours" is main. My workflow
rebases, which means the `--theirs` reflex is backwards in the operation I actually run.
**Never use either flag for a whole file.** Name the ref:

```bash
git checkout origin/main -- <path>     # main's version, in merge and rebase alike
git checkout MERGE_HEAD  -- <path>     # merges only
```

## 2. Triage before you resolve

Sort every conflicted file into three piles. Most conflicts in my repos are pile 1 or 2,
and hand-resolving those is the mistake.

**Pile 1 — lockfiles. Never merged by hand.**

```bash
git checkout origin/main -- flake.lock       # main's, wholesale
```

Then, only if this branch genuinely needed a newer pin, re-run `nix flake update <input>`
here. That one is raw on purpose: no wrapper covers a branch-local repin, and `bench ship`
works on main checkouts. Same shape for `package-lock.json` (take main's, `npm install`).

**Pile 2 — generated files. Regenerate, don't merge.** Take either side, then run the
generator and commit what it produces:

| File | Command |
|---|---|
| `content/docs/haus/reference/options.mdx` | `npm run options` |
| `src/data/bar-tables.json` | `npm run bar-tables:update` |
| the nebelung palette CSS | `npm run palette` |
| the keybinding tables | `npm run bindings:update` |
| `_bench` | **not generated** — a hand copy of `bench`'s usage header. Resolve it against `bench:2-54` |

**Pile 3 — real code and prose.** These get step 3, one hunk at a time.

## 3. Read why each side exists

For every hunk in pile 3, both sides, before you touch it:

```bash
git log --oneline -3 <side> -- <path>      # what landed, and its message
git log -S'<the conflicting text>' --oneline -- <path>
gh pr list --search '<path>' --state merged --limit 3
```

Read the commit message. If it names a PR or issue, read that too. You're after one
sentence per side: **what was this change for?** Quote it when you report.

If both sides trace back to the same intent, you're looking at a formatting collision and
it resolves itself. If they trace to different intents, that's the real decision.

## 4. Resolve

- **Compatible intents → keep both.** Two people added a case to the same match; the
  answer is both cases, not the newer one. This is most conflicts.
- **Incompatible → pick the side that matches what this merge is for**, and say in the
  commit message what you dropped and why. A dropped change that nobody names is a bug
  filed against you in three weeks.
- **Invent nothing.** Nothing may appear in the result that existed on neither side. If
  the honest resolution needs new code, that's a follow-up commit, not a hunk.
- **Prose conflicts are still conflicts.** Two AGENTS.md stanzas that contradict each
  other need one of them deleted, not both kept adjacent.
- **≥3/5 and genuinely ambiguous → stop and ask.** One message, both intents quoted, your
  pick, the reversal cost. Don't guess on something I'd feel.

## 5. Run the checks before you commit

A merge is the easiest place in git to produce code that satisfies both branches and
passes neither's tests. Find the repo's own loop and run it. **Build, never activate** —
`darwin-rebuild switch` is machine-wide and serial, and it's mine:

| Repo | Check |
|---|---|
| `~/.config/nix`, `haus`, a desktop | `nix build .#darwinConfigurations.mbp.system` — or `bench try` from the workshop, against local checkouts. Hand me `haus rebuild`; don't run it |
| `hausfold.co` | `npm test && npm run types:check && npm run lint` |
| a Swift app (pounce, perch, trill) | that repo's `script/test` or `swift build` |
| anything else | whatever its `AGENTS.md` says verify means |

Nix errors are verbose — read from the **bottom** up.

## 6. Finish it

```bash
git add <resolved>
git rebase --continue          # or: git merge --continue
```

**A rebase isn't done after one commit.** Keep going through every remaining commit,
repeating steps 2–4 for each; the same file can conflict several times and each one needs
its own answer. Only stop when git says the rebase is complete and the tree is clean.

Then push. On a `worktree-*` branch **force-push is free** — single-agent, nobody bases on
it: `git push --force-with-lease`. Never force-push `main`.

**Never `git merge origin/main` into a branch** to dodge a conflict. It puts commits I
didn't write into my PR's commit list. Rebase.

## 7. Report

In the `/brief` shape:

- **The verdict** — what conflicted and why, in one sentence.
- **Per real hunk**: the two intents, quoted from their commits or PRs, and which won.
- **Anything dropped**, named explicitly. This is the part I read.
- Which checks ran and passed. Which files were regenerated rather than merged.

Done means: the operation is finished, the tree is clean, the checks passed, and nothing
in the result came from neither branch.
