---
name: blast-radius
description: >-
  Find what a change could break somewhere else before it ships — beyond the diff — and
  prove the one fact it's safe because of by running real code, not by writing it up.
  Use when I say /blast-radius, "blast radius of X", "what could this break", "what
  does this touch", or when I hand you a small diff I don't trust yet.
---

# Blast radius — what does this break somewhere else?

Listing the callers is not the job; grep does that in a second. The job is the
breakage grep won't show you — and the proof, because a writeup that merely
sounds right is the trap.

## Don't trust your own writeup

A blast-radius writeup reads as convincing whether or not it's true. So don't
hand back the writeup: find the one or two facts the whole thing depends on and
prove them by running code. Words are where you start, not what you ship.

### The evidence ladder

For each fact the change's safety depends on, get it as far down this list as
is cheap, and say where it stopped:

1. **You said so.** Worthless on its own.
2. **You pointed at the line.** A real `file:line`, or the library's own source.
3. **You walked the failure and it doesn't reach.** Step by step, not vibes.
4. **You ran it.** A script or test that calls the real code and fails loud if
   you're wrong.
5. **You reproduced it in the running app.**

A safety fact stuck above step 4 gets said out loud — "unproven" — never
written up as settled. Step 4 is usually one small scratchpad script that
imports the exact library the app ships and calls the exact function you're
worried about.

## Steps

1. **Read the change.** The diff, the symbols it adds, changes and deletes, and
   what it now does differently — including the part the diff doesn't spell
   out. `gh pr view` / `gh pr diff` and the commit messages are part of the
   change.
2. **Find the one fact it's safe because of.** Most scary-looking changes are
   safe because of a single fact ("this call only drops already-dead cache
   entries and does nothing else"). Find it: if it holds, most of the scary
   cases die at once. Spend your time here, not on a long list of maybes.
3. **Look where grep stops.** The pinned version and any local patch of the
   library you call — read its actual source, not its README. When things run:
   launchd racing the GUI session, a teardown order, a microtask. What a symbol
   search misses: the JSON an API returns, a DB column, a wire format, another
   language reading the same bytes, a feature flag, code three hops downstream.
   In the family repos the hop grep always misses is the lock ripple: a
   nebelung or pounce change reaches this machine only through haus's lock, so
   a layer change's blast radius includes every consumer downstream — and
   `bench try` builds this machine against the local checkouts, which IS the
   step-4 proof for that.
4. **Be honest about each risk.** A real chance of happening and a real cost if
   it does. Keep the confirmed ones; list what you checked and cleared
   separately. Cite a real `file:line`; a search that finds nothing is still an
   answer; never invent a caller or an API.
5. **Prove the one fact.** Write the script, run it, paste what happened. Can't
   prove it cheaply → mark it unproven. Don't round up.
6. **Big or wide change?** Suggest `/code-review ultra` — launching it is mine
   (it bills), so hand me the command rather than running it. Different
   reviewers catch different real bugs.

## What to hand back

Through `brief`'s shape — the one safety fact, proven or marked unproven, IS
the verdict line.

- **What it does** — what changed, including the non-obvious part.
- **The one fact it's safe because of** — stated, ladder step named, proof
  pasted. Unproven if unproven.
- **Risks** — only the real ones: how each breaks, its `file:line`, likelihood,
  cost, and how to check.
- **Cleared** — what you checked and why it's fine.
- **Before you merge** — the cheapest test or repro that catches the real bug,
  including the script you wrote.

A writeup that leaves this pane (a PR body, an issue) goes through `unslop`
first, with anything private stripped.
