# CLAUDE.md

Personal machine config for one Apple Silicon Mac (host `mbp`, user `julienmartel`).

This repo is **thin**: it consumes the public [nebelhaus](https://github.com/nebelhaus/nebelhaus)
rice and adds only what's personal. The actual system/shell config lives in the
public modules, not here.

- `flake.nix` — ~18 lines: calls `nebelhaus.mkNebelhaus { username; hostname; host; }`.
- `hosts/mbp/default.nix` — the personal layer: identity, private apps, secrets.

The rice itself lives in sibling repos (clone under `~/code/nebelhaus/`):
- **[nebelhaus](https://github.com/nebelhaus/nebelhaus)** — the flake + modules
  (`den` `hearth` `prowl` `sill` `collar` `pounce`). System, shell, everything.
- **[pounce](https://github.com/nebelhaus/pounce)** — the command-palette app.
- **[nebelung](https://github.com/nebelhaus/nebelung)** — the theme.

## Rebuild (after any change)

```bash
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Build first, switch second — a failed build never touches the running system. Nix
errors are verbose; read from the *bottom* up for the actual cause.

## Where does a change go? (decision tree)

| You're changing…                                   | Do this |
|----------------------------------------------------|---------|
| A personal app (cask/brew), for this machine only  | `hosts/mbp/default.nix` → `homebrew.casks`/`brews` |
| Your identity (git name/email/signing, pounce cert)| `hosts/mbp/default.nix` → `nebelhaus.git.*` / `nebelhaus.pounce.signingIdentity` |
| A personal package / secret / private alias        | `hosts/mbp/default.nix` → `home-manager.users.${username}` |
| **The rice** (system defaults, WM, bar, shell, theming) | edit the module in `~/code/nebelhaus/nebelhaus`, commit + push, then `nix flake update nebelhaus` here + rebuild |
| **Pounce** (the app or its commands)               | edit `~/code/nebelhaus/pounce`, test with `rebuild-pounce` (see below), push, then `nix flake update nebelhaus` |

To pull the latest rice + theme + pounce: `nix flake update nebelhaus` then rebuild.

## Pounce dev loop

`rebuild-pounce` (alias in `hosts/mbp`) rebuilds the system against the **local**
`~/code/nebelhaus/pounce` checkout via `--override-input`, so you can iterate on
uncommitted pounce edits. A plain `darwin-rebuild` uses the pinned GitHub input
(reproducible). When happy: commit + push pounce, then `nix flake update nebelhaus`.

## Deeper docs

Operational gotchas that used to live here (launchd GUI race, pounce self-signing,
Homebrew tap-trust, Touch ID + zellij reattach, Determinate GC) now live with the
code that embodies them — see `~/code/nebelhaus/nebelhaus/CLAUDE.md`.

## Conventions

- Commits are GPG-signed. Keep messages imperative.
- Never commit secrets — they're loaded at runtime from `~/.secrets/` in the host's
  zsh `initContent`.
- `nixfmt` formats `.nix` files.
