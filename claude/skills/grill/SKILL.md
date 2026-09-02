---
name: grill
description: >-
  Interview me before you build — grounded in the actual docs and code first, one question
  at a time, each with a default I can accept by saying "yeah". Then write the answers
  where they belong: an AGENTS.md stanza, a comment beside the code, or the commit
  message. Use when I say /grill, "grill me", "interview me", "ask me first", "plan this
  with me", "poke holes in this", or before any change big enough that guessing wrong
  costs a rebuild.
---

# Grill — read first, ask second, write it down where it lives

A plan built on a guess is a plan I have to reject after you've written it. This is the
cheap version of that conversation: you read the material, you find the handful of forks
you genuinely can't call, you ask them one at a time, and the answers land somewhere a
future session will actually find them.

**Read before you ask.** A question the README already answers is worse than no question.

## 1. Ground yourself (silently)

Before the first question, read. No narration while you do it.

- **The repo's own rules** — `AGENTS.md` in this repo, its parent workshop, and the repo
  the change actually belongs to. The routing tables there answer "which repo" outright.
- **The code that already does something similar.** The strongest question in this whole
  skill is "there's already a pattern at `path:line` — same shape, or is this different?"
- **The real docs for anything third-party.** Fetch them. Version-specific behaviour, the
  option that doesn't exist, the API that changed — that's what makes a question grounded
  instead of generic. Say which page you read.
- **What shipped recently.** `git log --oneline -20` on the paths in play.

If grounding answers everything, **say so and skip to the work.** "Read the three files,
nothing here I can't call — building it" is a valid and good outcome of `/grill`.

## 2. Find the real forks

Score every open question on the `/brief` ladder. Ask only **≥3/5**.

| | |
|---|---|
| 1–2/5 | decide it, state the assumption in one clause, keep moving |
| **≥3/5** | costs a rebuild, a ripple, is hard to reverse, or I'd feel it — **ask** |

**Cap: 7 questions, and stop the moment the rest are ≤2/5.** Three good ones beat seven.
Kinds of fork worth my time, roughly in order:

1. **Scope** — where does this stop? The thing most likely to be wrong.
2. **Which repo** — the routing tables usually settle this. Only ask when they genuinely
   don't.
3. **Blast radius** — does anything already relying on the old behaviour break?
4. **Naming, once it's public.** A `haus.*` option name, a CLI verb, a published URL. These
   are 4/5 because renaming them later is a breaking change.
5. **The trade you can see and I can't** — you've read the code, I haven't.

Never ask: my preference on something reversible in one commit, permission to commit /
push / open a PR (you have it), or "should I proceed" (yes).

## 3. Ask, one at a time

Each question is one message and has four parts. Nothing else.

```
**<the fork, one sentence>** — <the one fact from step 1 that makes this a real fork>

A) <option>   B) <option>

I'd take A: <one clause why>. Going the other way later costs <what>.
```

- **One question per turn.** Never a numbered list of six. I answer the one in front of me.
- **Two options.** If you have five, you haven't finished thinking. Name the two live ones
  and say the rest are worse.
- **Always recommend.** A question without your pick is homework. You read the code.
- **"yeah" means your recommendation.** Take it and move to the next question. Don't
  confirm back.
- **Three or more genuinely-different options** → put the native picker in front of me
  instead of making me type: `printf 'a\nb\nc\n' | pounce -p "<the fork>"`.
- **Track what's answered.** If I go quiet mid-grill and come back tomorrow, restate the
  answers so far in three lines and continue from there.

**Push back when my answer fights the repo.** That's the whole value over a form: *"You
said the option should be `haus.bar.showClock`, but every other pill is
`haus.bar.items.<name>` — is this one deliberately different, or should it follow?"* One
push, then take my answer.

## 4. Write it down where it lives

**No new note store.** No `CONTEXT.md`, no `docs/adr/`, no scratch file of decisions —
those rot unread and my standing rule is against them. An answer worth keeping goes in
exactly one of three places:

| The answer is… | Goes |
|---|---|
| a rule that binds future work ("never X, because Y") | a stanza in the owning repo's **`AGENTS.md`**, in the section it belongs to |
| a reason this code looks wrong and isn't | a **comment beside the code** it explains |
| why this change, not the obvious alternative | the **commit message** |
| everything else | nowhere. It was scoped, not decided |

Write it **as you go**, not in a batch at the end — a grill I abandon halfway should still
have left the repo better. And write it in my voice, not as minutes: *"`_bench` is a hand
copy and can rot"*, not *"It was decided that…"*.

## 5. Land it

Close with the `/brief` shape: the verdict, the plan as ≤5 anchored steps, and where each
decision got written. Then **start building** — a grill that ends in a document and no
code is a meeting.

If the work is leaving this session, `/handoff` instead: the answers you just collected
are exactly what a cold lane needs.
