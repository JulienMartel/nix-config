# nix-config

Personal machine config for one Apple Silicon Mac (host `mbp`). This repo is a
**thin consumer** of the public [nebelhaus](https://github.com/nebelhaus/nebelhaus)
rice — it pulls the whole system + shell from there and adds only what's personal.

> Working on this config? See [`CLAUDE.md`](./CLAUDE.md).

## Layout

```
flake.nix               # ~18 lines: nebelhaus.mkNebelhaus { username; hostname; host; }
hosts/mbp/default.nix   # the personal layer: identity, private apps, secrets
```

Everything else — macOS defaults, AeroSpace, SketchyBar, the shell/terminal, the
pounce palette, the Nebelung theme — lives in the public modules, consumed via the
`nebelhaus` flake input.

## New machine

```bash
# 1. Install Determinate Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 2. Clone
git clone https://github.com/JulienMartel/nix-config.git ~/.config/nix
cd ~/.config/nix

# 3. Build & activate
nix build .#darwinConfigurations.mbp.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Then open a fresh terminal. Secrets (SSH/GPG keys, API tokens, `.gitcookies`) are
**not** in this repo — regenerate/transfer them by hand under `~/.secrets/` and
`~/.ssh`. Pounce needs a one-time Accessibility approval (see the nebelhaus README).

## Daily use

```bash
# Apply changes after editing hosts/mbp
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp

# Pull the latest rice/theme/pounce, then apply
nix flake update nebelhaus && sudo darwin-rebuild switch --flake .#mbp

# Rollback / inspect
darwin-rebuild --list-generations
darwin-rebuild --rollback
```

To change the rice itself (not just this machine), work in the
[workshop](https://github.com/nebelhaus/workshop) at `~/code/nebelhaus`: edit
the module repos there, `haus try` to test against the local checkouts without
pushing, then `haus ship` to push and ripple the lock updates back here.

## Requirements

macOS 15+ on Apple Silicon (`aarch64-darwin`).
