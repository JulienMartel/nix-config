# Nix Configuration (macOS)

Declarative macOS setup for an Apple Silicon Mac using [nix-darwin](https://github.com/LnL7/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager): packages, GUI apps, dotfiles, shell, and system preferences, all version-controlled.

> Working on this config? See [`CLAUDE.md`](./CLAUDE.md) for where things live and how to rebuild.

## Layout

```
flake.nix                      # entry point (inputs + darwinConfigurations.mbp)
hosts/mbp/configuration.nix    # system: packages, Homebrew casks, macOS defaults, launchd
home/home.nix                  # user: shell, programs, dotfile wiring
dotfiles/                      # raw configs symlinked by home.nix
  aerospace/  sketchybar/  ghostty/  zellij/
pkgs/                          # local packages (choose palette + choose-commands)
```

## New machine

```bash
# 1. Install Determinate Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 2. Clone
git clone https://github.com/JulienMartel/nix-config.git ~/.config/nix
cd ~/.config/nix

# 3. Build & activate
nix build .#darwinConfigurations.mbp.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Then open a fresh terminal. Secrets (SSH/GPG keys, API tokens, `.gitcookies`) are **not** in this repo — transfer or regenerate them by hand under `~/.secrets/` and `~/.ssh`.

## Daily use

```bash
# Apply changes after editing any file
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp

# Update all inputs to latest, then apply
nix flake update && sudo darwin-rebuild switch --flake .#mbp

# Rollback / inspect
darwin-rebuild --list-generations
darwin-rebuild --rollback
```

Packages are pinned in `flake.lock` (on `nixpkgs-unstable`), so updates only happen when you run `nix flake update` — reproducible and reversible.

## Requirements

macOS 15+ on Apple Silicon (`aarch64-darwin`).
