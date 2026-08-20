# Copilot instructions

**Read [`AGENTS.md`](../AGENTS.md) at the repo root first — it is the full,
authoritative instruction set for every agent working here, and this file is
only a pointer to it.** (Copilot doesn't follow file imports, hence the
duplication below; if the two ever disagree, `AGENTS.md` wins.)

The short version:

- This repo is **one Mac's personal layer** (host `mbp`), consuming the public
  [haus](https://github.com/hausfold/haus) layer as a flake input. It
  is deliberately thin: `flake.nix` and `hosts/mbp/default.nix`.
- **Almost nothing belongs here.** System defaults, tiling, the bar, the shell,
  theming — all of that is the rice's, in its own repo. What belongs here is
  identity, personal apps, secrets plumbing and host tweaks. A change that
  "works here" but belongs upstream is still wrong, and it gets overwritten the
  next time the lock moves.
- **Colors are never defined here** — the source of truth is the `nebelung`
  flake.
- **Prefer a `haus.*` option** to a raw `system.defaults.*` / `homebrew.*`
  line when one exists.
- **Never commit secret values.** `secretspec.toml` declares the names; the values
  live in the macOS login keychain via `secretspec`. The `.gitignore` is
  deliberately aggressive about `*secrets*`, keys and `.env` (with one negation
  so `secretspec.toml` itself stays committable).
- **Build before you switch:** `nix build .#darwinConfigurations.mbp.system`
  first — a failed build must never reach the running system. Nix errors read
  from the *bottom* up.
- Commits are GPG-signed, messages imperative; `nixfmt` formats `.nix`.

For review comments, the same bar applies as anywhere in the family:
correctness and boundaries (does this change belong in *this* repo?) over style.
