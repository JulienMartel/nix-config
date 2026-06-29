# CLAUDE.md

nix-darwin + home-manager config for one Apple Silicon Mac (host `mbp`, user `julienmartel`).

## Rebuild (do this after any change)

```bash
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Build first, switch second — a failed build never touches the running system. Nix errors are verbose; read from the *bottom* up for the actual cause.

## Where does config go? (decision tree)

| You're adding…                          | Put it in                                  |
|-----------------------------------------|--------------------------------------------|
| User CLI tool (just for me)             | `home/home.nix` → `home.packages`          |
| System CLI tool (root/all-users)        | `hosts/mbp/configuration.nix` → `environment.systemPackages` |
| GUI app                                 | `hosts/mbp/configuration.nix` → `homebrew.casks` |
| CLI that only exists as a brew formula  | `hosts/mbp/configuration.nix` → `homebrew.brews` |
| App Store-only app (no cask)            | install by hand; document in the casks comment block (mas is intentionally unused — it hangs) |
| Shell alias / env var / program config  | `home/home.nix`                            |
| A managed dotfile (aerospace, sketchybar, ghostty, zellij) | edit under `dotfiles/`; it's symlinked via `home.file` in `home/home.nix` |

Default to nixpkgs (`home.packages`/`systemPackages`) over Homebrew. Use Homebrew only for GUI casks and formulae missing from nixpkgs.

## Theme

Single source of truth is `catppuccin.flavor` in `home/home.nix`. Prefer enabling a program's catppuccin module integration (`catppuccin.<prog>.enable`) over hardcoding a `catppuccin-mocha` string. Raw dotfiles that nix can't inject into (ghostty `config`, zellij `config.kdl`) name the flavor manually — keep them in sync if the flavor changes.

## Gotchas

- **launchd GUI race**: GUI agents (AeroSpace, SketchyBar) launched at cold boot before the Aqua session is ready park with exit 78 (EX_CONFIG) and wedge. The `withGUIWait` wrapper in `configuration.nix` polls for Dock/Finder/SystemUIServer before exec. Don't "simplify" it away. To recover a wedged agent: `launchctl bootout` then `bootstrap`.
- **Homebrew tap-trust**: `HOMEBREW_NO_REQUIRE_TAP_TRUST=1` (via `/etc/homebrew/brew.env`) is required — third-party taps fail trust checks under sudo activation otherwise.
- **Determinate Nix owns the daemon**: `nix.enable = false`. Don't add a `nix.settings` block; config lives in `/etc/nix/nix.custom.conf`. GC is our own weekly launchd job (Determinate only GCs under disk pressure).

## Patterns

- **New `choose` command** (custom Swift command palette): add a `commands/<id>.sh`, register it in `pkgs/choose-commands/default.nix` (`name` / `description` / SF Symbol `icon` / `script`).
- **New SketchyBar plugin**: add `dotfiles/sketchybar/plugins/<name>.sh`, wire it into `dotfiles/sketchybar/sketchybarrc`. Follow an existing plugin (e.g. `harvest.sh`) for conventions.

## Conventions

- Commits are GPG-signed (key in git config). Keep messages imperative; this repo's history is the changelog.
- Never commit secrets (`~/.ssh`, `~/.gnupg`, `.gitcookies`, API tokens). Secrets are loaded at runtime from `~/.secrets/` in zsh `initContent`.
- `nixfmt` is the formatter for `.nix` files.
