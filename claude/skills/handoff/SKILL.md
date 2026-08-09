---
name: handoff
description: >-
  Turn something into a self-contained prompt for a FRESH agent session, copy it
  to the clipboard, and print it between clear begin/end markers. Use when I say
  /handoff (usually `/handoff <pasted text>`), "hand this off", "make me a
  handoff", "write a prompt for a new pane/session/agent", "I want to start this
  somewhere else", or when a piece of work has to leave this session and survive
  the transition. With no paste, it hands off THIS session.
---

# Handoff: a prompt a cold agent can act on

The next session knows **nothing**. Not this repo, not what we tried, not what
"it" refers to. A handoff is not a summary of what happened here — it's the
smallest brief that lets someone with zero context take the next action
correctly. Anything that doesn't change what they'd DO is noise; anything they'd
have to rediscover is a bug.

## Two modes, same output

- **`/handoff <pasted text>`** — the usual one. I've copied something an agent
  said (a finding, a plan, a diagnosis, a chunk of a thread) and want it turned
  into a prompt. **The paste is the source of truth**: distill it, don't
  augment it from your own guesses. You may add what you can *verify* cheaply
  right now (the repo, the branch, whether a named path exists) and nothing else.
- **`/handoff` alone** — hand off THIS session: what we're doing, where it
  stands, what's next. Same shape, sourced from the conversation.

## The steps

1. Resolve the facts you can. `git rev-parse --show-toplevel`,
   `git branch --show-current`, `gh pr view --json number,url` if a PR exists —
   cheap and read-only. Never guess a path, a branch or a command; if the paste
   names a file, `ls` it before writing it down.
2. **Write the prompt to a file**, don't compose it in your head:
   `<scratchpad>/handoff-<hh-mm-ss>.md` (or `/tmp` if there's no scratchpad). A
   fresh name each time — a second `/handoff` in one session must not overwrite
   the first, since by then the clipboard has moved on and the file is the only
   copy left.
3. **Copy it:** `pbcopy < <that file>`. If `pbcopy` isn't there, say so in one
   line instead of pretending it worked.
4. **Print it** between the markers below.
5. Stop. No follow-up offer, no "let me know if". If something essential was
   missing, one line after the closing marker naming exactly what — see Gaps.

## Shape of the prompt

Aim for **150 words, hard cap 250**. Every line earns its place; drop any
heading with nothing real under it rather than writing "N/A".

```
<One sentence: what the next session must accomplish. Imperative, not a topic.>

Where: <repo> · branch <branch> · <repo-relative/path:line>, <path:line>
State: <2-4 sentences — what is already true, what was tried and rejected and
        why, what decision is already made. Past tense, load-bearing only.>
Verified: <what was actually run, and its result. "not verified" if it wasn't.>
Next: <the first concrete action, as a command or an edit at a path:line.>
Watch out: <the one gotcha that costs 20 minutes if they don't know it.>
```

## Rules that make it usable cold

- **No pronouns without antecedents.** "it", "the file", "that approach" become
  the actual name. This is the single most common way a handoff fails.
- **Verbatim commands and real branch names**, never a paraphrase. Paths outside
  any repo (a scratch file, a log) go absolute — a fresh pane may start in a
  different cwd.
- **Name the repo and the branch, not just the checkout path.** In an agent
  worktree `git rev-parse --show-toplevel` gives
  `~/.cache/claude-worktrees/<repo>/<name>`, which `holt` **deletes** when the
  pane closes (the work is parked on the branch first). The branch is the
  durable handle — `holt <name>` rebuilds the checkout around it. Give paths
  inside the repo as repo-relative, so they survive wherever it gets checked out.
- **Say what's unproven.** "Builds, not feel-tested" is worth more than a
  confident "done". A handoff that overstates state is worse than none.
- **Carry the constraints, not the history.** "We decided X over Y because Y
  breaks Z" — one line. Nobody needs the path we walked to get there.
- **Don't re-derive.** If the paste already contains a good finding, keep its
  wording; you're compressing and grounding it, not rewriting it.
- **Never invent.** No plausible file names, no assumed test commands, no
  imagined next steps. Unknown is a fact and gets written down as one.
- No greeting, no "you are an agent that…", no praise, no closing pleasantry.

## Print format — exact

The clipboard is how it actually travels; this print is so I can eyeball it and
see where it starts and stops in a wall of transcript. Use these markers
verbatim, on their own lines:

````
━━━━━━━━━ HANDOFF BEGINS ━━━━━━━━━ (copied to clipboard)

<the prompt, exactly as it was copied>

━━━━━━━━━ HANDOFF ENDS ━━━━━━━━━
````

Wrap the prompt in a fenced block *inside* those markers so its own formatting
survives; if the prompt itself contains a fence, use a longer one on the outside.

## Gaps

If the paste is too thin to ground — no repo, no path, no concrete objective —
produce the best handoff the material supports, mark the holes inline as
`UNKNOWN: <what>`, and add exactly one line after the closing marker: the single
thing that would most improve it. Do not interrogate me for five fields, and do
not refuse to produce one.
