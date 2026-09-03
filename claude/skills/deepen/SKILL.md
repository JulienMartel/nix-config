---
name: deepen
description: >-
  Survey a codebase for deepening opportunities — modules where a shallow interface could
  hide more behind less — and hand me a dark, nebelung-styled HTML report of ranked
  candidate cards. Read-only: it never edits code. Use when I say /deepen, "what's worth
  refactoring", "architecture pass", "survey this codebase", "where's the friction",
  "how do we make this change easy", or before a feature that will fight the current
  seams.
---

# Deepen — survey for depth, report, don't touch

A deep module puts a lot of behaviour behind a small, stable interface; a shallow one
makes every caller carry its implementation. This skill finds the handful of places where
deepening would actually pay, ranks them, and hands me a report I can read in two
minutes. **It never edits code.** The change happens in a later session, one candidate at
a time, and starts with `/grill`.

## 1. Scope by what moves

Unless I name an area, bias the survey to the code that actually changes:

- `git log --oneline -50` (or `--since='3 months ago'`) → the paths that keep appearing.
- A commit that had to touch four files to say one thing is a candidate announcing
  itself. Collect those commits; they become the friction evidence on the card.
- **Dormant code loses ties.** A perfect refactor of a module nobody has touched in a
  year pays nothing. Speculative at most, usually nothing.

Ground silently first, the way `/grill` does: the repo's AGENTS.md, the workshop routing
table, and the code around each smell — before writing a word of report.

## 2. What counts — two filters, both must pass

Shallowness shows up three ways:

- **A seam that serves the tests, not the callers** — pure functions extracted only so
  something could be unit-tested, leaving the caller to reassemble the concept.
- **One concept smeared across a seam** — two modules that each leak implementation
  detail the other must know to be used correctly.
- **A concept that costs N file-opens** — understanding one behaviour means holding four
  files in your head at once.

Every candidate then passes both filters or dies:

1. **Deletion test.** Imagine the module gone. If its complexity would *concentrate*
   behind a smaller interface somewhere, it passes. If it would *spread* into every
   caller, the module is already pulling weight — leave it alone.
2. **Payoff relevance.** The friction sits on a path that moves — recent commits, or
   work I've named as coming. Elegance on a frozen path is not a finding.

Three real candidates beat ten padded ones. An honest "nothing here worth deepening" is
a valid and good report.

## 3. Route before you rank

This machine's repos are a family, and a smell found *here* is often owned *elsewhere* —
the routing table in AGENTS.md decides. A candidate whose real owner is another repo
(the layer in `~/code/workshop/haus`, the palette in nebelung, the app in pounce) gets a
**routed card**: name the owning repo and path, and the action line is a session there —
`/handoff spawn <repo>` — never a fix in place. And any command a card mentions speaks
the family verbs — `bench try`, `haus rebuild`, `bench ship`, `scruff park` — never the
raw `nix`/`git` they wrap.

## 4. The report

One HTML file. Each candidate is a card:

- **Files** — the paths involved, as code.
- **Friction** — concrete, not vibes: the commits that had to straddle the seam, the
  file-open count, the caller that reassembles the concept.
- **The fix, in plain English** — what the deeper interface hides, one paragraph.
  Benefits framed as locality and leverage, not beauty.
- **Before/after** — two stacked interface boxes drawn in surface tokens, one idea per
  diagram. Plain HTML/CSS or inline SVG.
- **A badge:**

| Badge | Means | Colour |
|---|---|---|
| **Strong** | deletion test passes clearly and the friction is real | green |
| **Worth exploring** | plausible; payoff depends on where the repo is going | yellow |
| **Speculative** | surfaced for completeness; safe to ignore | muted |

Above the cards, **one top recommendation** in mauve, with the reason in a sentence.

### The visual standard — hausfold.co/design.md

- **Dark only.** No light theme, no `prefers-color-scheme`.
- **Every colour is a `var(--nebelung-*)` token**, defined inline in the page — a
  hardcoded hex outside the token block is a defect. The quick reference (vendored;
  nebelung stays the source of truth):

  > Ground `#121212` (crust) · card `#202020` (base) · tile `#343434` (surface0) · gray
  > shapes `#494949`/`#5c5c5c` · text `#d7d7d7` · muted `#aeaeae` · accents: mauve
  > `#c9a8f1`, peach `#f5b58e`, yellow `#f7e2b5`, green `#abe1a6` · face Space Grotesk ·
  > wordmarks lowercase 600/+0.06em · radii 24/28 · dark only · no shadows · no motion.

  Plus, as vars for the badges and callouts: danger red `#ed8fa9`, info teal `#9be0d5`,
  eyebrow `overlay1` `#858585`, border `surface1` `#494949`.
- **Self-contained.** The upstream's known failure mode is a blank report when its CDN
  Tailwind and Mermaid are blocked. So: no CDN scripts, no Mermaid, all CSS inline,
  diagrams in plain markup. Space Grotesk via the Google Fonts link with a `sans-serif`
  fallback is the one external reference allowed — the report must still read styled
  without it.
- **Elevation is surface steps** — base → surface0 → surface1 — never shadows. Radii 24
  for cards, 999 for badge pills. UPPERCASE only for wide-tracked section eyebrows
  (12/600/+0.18em, overlay1). Mauve is the accent; nothing competes with it. No motion.

### Delivery

Write the file to the **session scratchpad** and **send it to me**. Don't open a
browser, don't take the screen, don't commit it — the report is ephemeral by design
(see Memory).

## 5. I pick a candidate → `/grill`

The upstream runs its own interview phase here. Mine doesn't: **load `grill`** and let
it do what it already does — ground, find the ≥3/5 forks, ask one at a time with a
recommendation, push back when my answer fights the repo. The card's friction evidence
is grill's grounding, pre-done.

**One candidate per session.** Deepening two at once fills the context with the first
one's corpse.

## 6. Memory — where anything worth keeping lands

**No new note store.** No `CONTEXT.md`, no `docs/adr/`, no scratch file of decisions —
those rot unread and my standing rule is against them. The upstream reads and writes
both; that is exactly the part that doesn't survive the port. A decision worth keeping
goes in one of three places, written by the session that *acts* on the candidate:

| The decision is… | Goes |
|---|---|
| a rule that binds future work ("never X, because Y") | a stanza in the owning repo's **AGENTS.md** |
| a reason this code looks wrong and isn't | a **comment beside the code** it explains |
| why this change, not the obvious alternative | the **commit message** |

The report itself is none of these — it's a scratchpad artifact, and losing it costs
nothing a re-run won't recover.

## Never

- **Edit code from this skill**, however obvious the fix looks. Survey and report only.
- **Fix in place a finding another repo owns** — route it (§3).
- **Create `CONTEXT.md`, `docs/adr/`, or any decision log** (§6).
- **Pad the report.** Speculative cards exist for completeness, not for volume.
