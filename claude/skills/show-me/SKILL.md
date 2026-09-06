---
name: show-me
description: >-
  Explain what's in front of us as the smallest picture that carries it — pseudocode, a
  call tree, a component or file tree, a text sequence, a diff of the target shape — and
  only when text can't hold the point, one nebelung-styled HTML page handed to me, never
  opened on my screen. The explain half of `brief`: the skeleton relaxes, the sketch
  replaces the paragraphs. Use when I say /show-me, "show me", "sketch it", "draw it",
  "what does this look like", "how does X flow", "what's the shape of this", "diagram
  this", or whenever an explanation is about to run past one paragraph.
---

# Show me — the picture is the paragraph

`brief` relaxes when I ask you to explain, teach or compare. This is what relaxed looks
like when the thing has a shape. I hold one thing in working memory: a tree is one thing,
three paragraphs are three. So — verdict line, then the sketch, then at most a few lines
beside it. Prose sits *under* a picture, never around it.

humanlayer's `show-me`, with three house rules on top: text first (a pane can't draw
Mermaid), every node carries its path, and the HTML page is handed over, never opened.
Everything else `brief` says still holds — no preamble, verdict first, real names only.

## 1. Pick the smallest view

One form, chosen by what the question is about. Rarely two. Never all of them.

| The question is about | Draw |
|---|---|
| logic, an algorithm, a state machine | **pseudocode** — `on(x)` / `if` / `return`, indented, no syntax |
| what calls what at runtime | **call tree** — entry point at the root, one indent per hop |
| a UI | **component tree** — hooks and the state they own inline, module boundary in parens |
| who owns what; a refactor's before/after | **shallow file tree** — one `#` per dir saying what it *owns* |
| interaction over time, data flow, two processes talking | **text sequence** — `a → b : message`, one line per exchange |
| what changes | **a diff of the shape** (§3) |
| a fork I have to pick | **one shape per option** (§4) |
| a target I'll copy | **the real code block** — only when most of it is new, or when cutting context would hide ownership or order |

Keep only the calls, files, props, states and boundaries that answer the *current*
question. A call tree of the whole daemon when I asked about one edge is noise with
indentation.

## 2. The terminal is the canvas

- **Text renders everywhere** — a Claude Code pane, a Codex or OpenCode pane, an issue
  body, a commit message. A ```mermaid fence in a pane is source, not a picture, and in
  a file you send me it is a CDN request that gets blocked. The one place Mermaid draws
  is a client's own artifact viewer; default to the text forms and reach for Mermaid
  only inside a page a client renders it in.
- **Every node that is a file carries its path** — `path` on a tree node, `path:line`
  on a call — so the sketch doubles as the map of where to go next. `brief`'s anchor
  rule, applied to a picture.
- **Every box is grep-able.** A function, file, component, process or option that
  exists. No `Handler` and `Service` invented to fill a level.

A call tree, from this repo's own docs:

```text
haus rebuild                                        # what /rebuild runs
  nix build .#darwinConfigurations.mbp.system       #   fails → nothing touched
  sudo ./result/sw/bin/darwin-rebuild switch        #   /etc/sudoers.d/darwin-rebuild: NOPASSWD
```

A file tree, the same repo:

```text
~/.config/nix/
├── flake.nix                 # 18 lines: haus.mkHaus { username; hostname; host; }
├── hosts/mbp/default.nix     # the personal layer — identity, apps, secrets, my instructions
└── claude/skills/<name>/     # my skills; symlinked out-of-store, live-editable
```

A sequence — the lock ripple `bench ship` runs:

```text
me        → nebelung       : edit the palette, commit
bench     → pounce         : flake.lock ← nebelung, push
bench     → haus           : flake.lock ← pounce, nebelung, push
bench     → ~/.config/nix  : flake.lock ← haus, commit        # then haus rebuild
```

## 3. Diff the shape

When the surrounding shape already exists, show only what moves, as a `diff` of the same
form — the tree, the stack, the flow. Unchanged lines stay for orientation; everything
else is `+`/`-`. Match the diff to the topic: a component change diffs a component tree,
a layout change diffs a file tree, a behaviour change diffs the pseudocode.

```diff
 hosts/mbp/default.nix
   haus.ai.instructions              # the skill list gains `show-me`
   home.file.".claude/skills/…"
+    show-me                         # out-of-store, live-editable
   home.file.".agents/skills/…"
+    show-me                         # Codex and OpenCode see it too
```

```diff
 on(save)
-  write content
+  if content is unchanged
+    return cached result
+  write new content
+  invalidate cache
```

## 4. A fork is two shapes

`brief`'s **Need from you** block and every `grill` question offer two options. When the
options are structural, each gets a shape, labelled A and B, then the question and your
pick as usual. Two shapes beat two paragraphs — I can *see* which one is uglier.

```text
A — drafts stay in chat.db              B — drafts in our own sqlite beside it
  trill/src/db.rs   read-write            trill/src/db.rs      read-only
  ✗ Messages.app holds the write lock     trill/src/drafts.rs  new, ~40 lines
```

Stack them; side by side only when both fit in 80 columns.

## 5. HTML — the last resort, not the first

When the point is visual — a layout, a state comparison with more than two dimensions, a
concept a tree flattens — one HTML file about one point. Not a deck, not a tour.

- **The visual standard is `deepen`'s** (its §4, vendored from hausfold.co/design.md):
  nebelung tokens, dark only, self-contained, no CDN scripts, no shadows, no motion.
  Colours by role from the `nebelung` skill's `references/palette.md`, never by eye. A
  product's own UI (a client's app) wears that product's colours instead.
- **Real labels, real data, real paths.** The grep-able rule doesn't relax because the
  medium changed.
- **Delivery:** write it to the session scratchpad and **send it to me** — the client's
  file-send, or its artifact where it has one. **Never `open` it**: that takes the
  screen, and the screen belongs to the person at it. Never commit it — a sketch is
  ephemeral, and a re-run recovers it.

## Never

- **`open` the file**, or anything else that moves the pointer or takes focus.
- **The whole system** when I asked about one edge.
- **Several forms for one point.** One picture; a second only if it answers a different
  question.
- **A node that doesn't exist.** If you can't `grep` it, it isn't on the sketch.
- **Prose that repeats the picture.** If the tree says it, don't say it again.
- **Mermaid in a pane.**

---

## Worked example

**Before** — three paragraphs I lose my place in:

> So the way a colour change reaches your machine is a bit involved. nebelung is its own
> flake with the palette in it. pounce consumes nebelung as a flake input, and haus
> consumes both pounce and nebelung. Then this repo consumes haus. So when you change a
> colour you need to bump the lock in pounce, then in haus, then here, and then rebuild.
> There's a command that does this for you, I think it's bench ship, which… [two more]

**After**:

> **A palette edit reaches this Mac through three lock bumps, and `bench ship` does all
> three.**
>
> ```text
> nebelung            edit the palette, commit
> └─ pounce           flake.lock ← nebelung
>    └─ haus          flake.lock ← pounce, nebelung
>       └─ ~/.config/nix   flake.lock ← haus      # then haus rebuild
> ```
>
> To judge it before shipping: `bench try switch` builds against the local checkouts, no
> push (~1 min).

What changed: the finding moved to word one, the four hops became one tree with the
verb beside it, and the one command I'd actually run is the last line.
