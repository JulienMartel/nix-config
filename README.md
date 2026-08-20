# nix-config

Personal machine config for one Apple Silicon Mac (host `mbp`). This repo is a
**thin consumer** of the public [haus](https://github.com/hausfold/haus)
rice — it pulls the whole system + shell from there and adds only what's personal.

> Working on this config? See [`CLAUDE.md`](./CLAUDE.md).

## Layout

```
flake.nix               # ~18 lines: haus.mkHaus { username; hostname; host; }
hosts/mbp/default.nix   # the personal layer: identity, private apps, secrets
```

Everything else — macOS defaults, AeroSpace, SketchyBar, the shell/terminal, the
pounce palette, the Nebelung theme — lives in the public modules, consumed via the
`haus` flake input.

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

Then open a fresh terminal. Secret VALUES are **not** in this repo, and this
machine currently needs none: nothing here reads a secret. If that changes, add a
`secretspec.toml` declaring the NAME (never the value) and `secretspec set NAME`
stores it in the macOS login keychain. SSH/GPG keys and `.gitcookies` still
transfer by hand under `~/.ssh`. Pounce needs a one-time Accessibility approval (see the haus README).

## Daily use

```bash
# Apply changes after editing hosts/mbp
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp

# Pull the latest rice/theme/pounce, then apply
nix flake update haus && sudo darwin-rebuild switch --flake .#mbp

# Rollback / inspect
darwin-rebuild --list-generations
darwin-rebuild --rollback
```

To change the rice itself (not just this machine), work in the
[workshop](https://github.com/hausfold/workshop) at `~/code/workshop`: edit
the module repos there, `bench try` to test against the local checkouts without
pushing, then `bench ship` to push and ripple the lock updates back here.
(`bench` is the workshop's cross-repo CLI — formerly named `haus`, which now
refers only to the rice's own single-machine CLI.)

## Requirements

macOS 15+ on Apple Silicon (`aarch64-darwin`).
