---
name: unslop
description: >-
  Strip the AI tells out of reader-facing copy and put a human voice back in — docs,
  landing pages, READMEs, release notes, App Store text, issue and PR bodies, email.
  Use when I say /unslop, "un-AI this", "this sounds like a robot", "make it sound less
  AI", "too many em dashes", "read that back", or when I paste copy and wince. ALSO a
  standing rule: run the checklist over any reader-facing copy you write before you hand
  it to me, without being asked.
---

# Unslop — de-slop copy, then give it a voice

Two failures, not one. **Slop** is the machine tells: em dashes, "seamlessly", "not just
X but Y", a bold label and a colon. **Sterility** is what you get when you strip those and
stop — voiceless, structurally perfect, and just as obviously generated. Fixing the first
and causing the second is the common mistake. Do both passes or neither.

## Scope — the rule that stops this doing damage

**Em dashes and voice rules apply to copy a reader sees. They do not apply to internal
docs, and my internal docs are full of em dashes on purpose.** Getting this backwards
means "fixing" AGENTS.md files that were already right.

| | Copy (all rules) | Internal (universal rules only) |
|---|---|---|
| | `content/docs/**`, landing pages, `README.md`, frontmatter `description`, `<title>` and `og:` titles, release notes, App Store text, issue/PR bodies, email, anything a user reads | `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, `.agents/**`, `docs/` inside a repo, code comments, commit messages |

Universal rules — chatbot phrases, sycophancy, curly quotes, cutoff disclaimers — are
wrong in both. Everything else is a copy rule.

Three carve-outs, all real:

- **Generated files are fixed upstream or not at all.** `reference/options.mdx` renders
  haus's own option descriptions; `bar-tables.json` and the palette CSS are generated.
  Editing them is editing the wrong file. The scanner skips them.
- **Quotations keep their author's punctuation.** So do URLs, filenames and identifiers.
- **This file uses em dashes and is correct.** Don't "fix" it.

## 1. Scan — the mechanical pass

```bash
~/.config/nix/claude/skills/unslop/unslop-scan            # files I changed vs HEAD
~/.config/nix/claude/skills/unslop/unslop-scan PATH...    # a file, or a whole dir
~/.config/nix/claude/skills/unslop/unslop-scan --fix PATH # curly quotes + nbsp only
```

It masks code fences, inline code, URLs and link targets first, so it never fires on an
identifier. Exit 1 means hits. `--all` runs copy rules on internal files too (rarely what
you want), `--passive` adds a noisy passive-voice pass, `--json` for machine reading.

**A clean scan is not a clean page.** The scanner sees punctuation and vocabulary. It
cannot see a paragraph that says nothing.

## 2. Rewrite — what the script can't see

Read the copy. In order of how much damage each does:

1. **Sentences that name a feeling instead of a mechanism.** "the database stays close at
   hand", "types that follow your schema". Replace with the fact or the number:
   "`.toSQL()` returns the string sent to the database", "a column rename fails the
   build". **The test: could this sentence appear unchanged in another project's docs? Then
   it says nothing about this one — cut it.**
2. **Colons as mid-sentence connectors.** A colon before a list or a genuine payoff is
   house style and stays. A colon propping up a comparison ("If you're coming from X:
   instead of…") is a crutch. End the sentence.
3. **Rule of three.** Three examples because three sounds finished. Use the real number.
4. **False ranges.** "from X to Y" where X and Y aren't on a scale. List them.
5. **Synonym cycling.** Picked four words for one thing to avoid repeating. Repeat.
6. **Dense sentences.** If I have to backtrack to parse it, split it. One idea each.
7. **Passive with a known actor.** "queries are validated" → "the compiler validates
   queries". Passive is fine only when the actor genuinely doesn't matter.
8. **Adverbs propping up weak verbs.** "runs quickly" → "is fast", or the number.
9. **Structure that's too even.** Six bullets of identical length, every section the same
   shape. Real writing is lumpy.

## 3. Put a voice back

The house voice: *a person who knows the system explaining it to a friend.* Match the file
you're in; `haus/rooms/bar.mdx` is the reference.

- **Lead with the point.** What it does and why you'd want it, then the mechanics.
- **Have an opinion.** React to the fact instead of listing both sides evenly.
- **Show the command.** A block someone can paste beats a description of one.
- **Fun, lightly.** One good line per page, not one per paragraph, and never at the
  reader's expense while they're stuck.
- **Vary the rhythm.** Short. Then one that takes its time and earns the length.
- **Under-promise.** Say what's read-only, what needs a permission, what's a non-goal.
  Honesty is the house's whole tone.

## 4. Never strip these

The over-correction that loses more than it fixes:

- **A caveat, a limit, or a gotcha.** Slop-hunting that deletes the ⚠️ made it worse.
- **A load-bearing repetition.** Saying the dangerous thing twice is deliberate.
- **A specific number, path, command or version.** Specificity is the opposite of slop.
- **A first person "I".** It isn't unprofessional and it isn't a tell.
- **My jokes.**

## 5. Self-audit, then report

Ask once: *"reading this cold, what would make me guess a machine wrote it?"* Fix what
that surfaces. Then report in the `/brief` shape: the verdict, what you changed by
category (not a diff), and anything you deliberately left because it was already right.

## House constants — get these wrong and the copy is wrong

| | |
|---|---|
| Title/`og:` separator | `·`, never an em dash |
| The word for an installable config | **desktop**. "rice" only in quotations, URLs and identifiers |
| **haus**, the layer | never "opinionated" — that's the whole product argument. A *desktop* may be opinionated; the layer and the org may not |
| hausfold | sells nothing, ever. No price, no checkout, no urgency, no CTA voice |
| Contact address | `julien@hausfold.co`. Not `support@`, not `hi@` — informality is the point |
| Headings | sentence case, no decorative emoji. 🚨 ⚠️ 🔒 are internal markers, not copy |
| The recurring phrase | *the settings you always change by hand* — name the macOS pain, not a stance |
