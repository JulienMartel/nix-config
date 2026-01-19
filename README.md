# Nix Configuration (macOS)

Declarative macOS system configuration using nix-darwin and home-manager.

## Features

- Declarative package management (CLI tools + GUI apps)
- Reproducible dotfiles and shell configuration
- Version-controlled system preferences
- Easy setup on new machines

## Structure

```
~/.config/nix/
├── flake.nix                  # Main configuration entry point
├── flake.lock                 # Locked dependency versions
├── hosts/
│   └── mbp/
│       └── configuration.nix  # System-level config (packages, Homebrew, macOS settings)
├── home/
│   └── home.nix              # User-level config (dotfiles, shell, programs)
└── dotfiles/                  # Additional configuration files
    └── aerospace.toml
```

## Quick Start (New Machine)

### 1. Install Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 2. Set Up SSH Keys (for private repo)

Transfer existing keys or generate new ones:

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "julienbmartel@gmail.com"
cat ~/.ssh/id_ed25519.pub  # Add to GitHub
```

### 3. Clone Config

```bash
git clone git@github.com:JulienMartel/nix-config.git ~/.config/nix
cd ~/.config/nix
```

### 4. Build & Activate

```bash
nix build .#darwinConfigurations.mbp.system
./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

### 5. Restart Terminal

Open a new terminal to load the updated shell configuration.

## Making Changes

After editing configuration files:

```bash
cd ~/.config/nix
darwin-rebuild switch --flake .#mbp
```

For home-manager only changes:

```bash
home-manager switch --flake ~/.config/nix
```

## Common Commands

```bash
# Update flake inputs (nixpkgs, etc.)
nix flake update

# Search for packages
nix search nixpkgs <package-name>

# List generations (for rollback)
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild --rollback

# Garbage collect old generations
nix-collect-garbage -d
```

## Secrets Management

**NEVER commit:**
- SSH keys (`~/.ssh/`)
- GPG keys (`~/.gnupg/`)
- Credentials (`.gitcookies`, API tokens)
- `.env` files

These must be transferred manually or regenerated on new machines.

## System Requirements

- macOS 15+ (tested on macOS Sequoia)
- Apple Silicon (M1/M2/M3/M4) - architecture: `aarch64-darwin`

## Packages Installed

### System Packages (nix-darwin)
- bat, fzf, delta (git-delta), gh, glow, gnupg
- lazygit, lsd, neofetch, tree, ttyd, biome

### GUI Apps (Homebrew casks via nix-darwin)
- aerospace, ghostty, jordanbaird-ice, legcord, stats

### User Packages (home-manager)
- fnm (Node version manager)

## Shell Configuration

Zsh is configured with:
- Zinit plugin manager
- zsh-syntax-highlighting, zsh-autosuggestions, zsh-completions
- fzf-tab for completion
- Oh-My-Zsh git, sudo, and command-not-found plugins
- Starship prompt
- Aliases: `cat` → bat, `ls` → lsd, `lg` → lazygit

## Git Configuration

- GPG commit signing enabled
- Delta pager with catpuccin-latte theme
- Auto-setup remote for pushes
