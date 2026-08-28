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

The layer ships its own CLI, `haus` — on PATH from the first switch onward.
The raw `nix build` + `darwin-rebuild` pipeline above is only for the
bootstrap, before `haus` exists; after that, the verbs are the interface:

```bash
# Apply changes after editing hosts/mbp (builds first; a failed build never switches)
haus rebuild

# Pull the latest haus/theme/pounce, then apply
haus update

# Rollback / inspect
haus generations
haus rollback
```

To change the rice itself (not just this machine), work in the
[workshop](https://github.com/hausfold/workshop) at `~/code/workshop`: edit
the module repos there, `bench try` to test against the local checkouts without
pushing, then `bench ship` to push and ripple the lock updates back here.
(`bench` is the workshop's cross-repo CLI — formerly named `haus`, which now
refers only to the rice's own single-machine CLI.)

## Requirements

macOS 15+ on Apple Silicon (`aarch64-darwin`).
