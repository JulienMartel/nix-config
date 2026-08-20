# AGENTS.md

Personal machine config for one Apple Silicon Mac (host `mbp`, user
`julienmartel`).

This repo is **thin**: it consumes the public
[haus](https://github.com/hausfold/haus) layer and adds only what's personal.
The actual system/shell config lives in the public modules, not here.

- `flake.nix` — 18 lines: calls `haus.mkHaus { username; hostname; host; }`.
- `hosts/mbp/default.nix` — the personal layer: identity, private apps, secrets,
  and `haus.ai.instructions` (the global agent instructions every client on this
  machine reads).

**This file is the one set of instructions, for every agent** — Claude Code,
Codex, OpenCode, Cursor, Copilot alike, directly or through a one-line pointer.
Per-client wiring lives in that client's own file; the content stays here or in
[`.agents/`](./.agents/README.md).

The layer itself lives in sibling repos, checked out under `~/code/workshop`
(the [workshop](https://github.com/hausfold/workshop)):

- **[haus](https://github.com/hausfold/haus)** — the flake + modules (`core`
  `terminal` `windows` `bar` `security` `launcher` `shelf` `focus` …). System,
  shell, everything. The desktop it ships is `hacker`.
- **[pounce](https://github.com/hausfold/pounce)** — the command-palette app.
- **[nebelung](https://github.com/hausfold/nebelung)** — the theme.

The workshop's `bench` CLI drives the cross-repo flow: `bench status` (what's
stale where), `bench try [switch]` (build/run this machine against the LOCAL
checkouts — test without pushing), `bench ship` (push + ripple the lock
updates), `bench rebuild` (plain pinned rebuild). Don't confuse it with `haus` —
that is the layer's own end-user CLI (`haus
rebuild`/`update`/`rollback`/`doctor`/…), which drives THIS machine only and
knows nothing about the workshop.

## Am I in the right repo? (routing)

**This repo owns only THIS MACHINE's personal layer** — apps, identity, secrets,
host tweaks. The layer itself lives elsewhere.

| Want to change… | Repo |
|---|---|
| this machine's apps / identity / secrets / host tweaks | `~/.config/nix` ← **you are here** |
| the desktop: macOS defaults, tiling (`windows`), the menu bar (`bar`), the shell (`terminal`), Touch ID + firewall (`security`) | `~/code/workshop/haus` |
| the pounce palette app or its commands | `~/code/workshop/pounce` |
| colors / the theme palette | `~/code/workshop/nebelung` |

> **Whatever agent you are, enforce this.** If a request targets a different
> repo than the one whose files you're in, STOP and say so before editing — e.g.
> "That's a bar tweak; it lives in the layer at
> `~/code/workshop/haus/modules/bar`. Want me to switch to that repo?" Don't
> make the change in the wrong place. After the owning repo is edited + pushed,
> the consumer here pulls it via `nix flake update <input>` + rebuild.

## Rebuild (after any change)

```bash
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Build first, switch second — a failed build never touches the running system.
Nix errors are verbose; read from the *bottom* up for the actual cause.

## Where does a change go?

| You're changing… | Do this |
|---|---|
| A personal app (cask/brew), for this machine only | `hosts/mbp/default.nix` → `homebrew.casks`/`brews` |
| Your identity (git name/email/signing, pounce cert) | `hosts/mbp/default.nix` → `haus.git.*` / `haus.launcher.signingIdentity` |
| A personal package / secret / private alias | `hosts/mbp/default.nix` → `home-manager.users.${username}` |
| The global agent instructions every client reads | `hosts/mbp/default.nix` → `haus.ai.instructions` |
| **The layer** (system defaults, WM, bar, shell, theming) | edit the module in `~/code/workshop/haus`, test with `bench try`, commit, then `bench ship` |
| **Pounce** (the app or its commands) | edit `~/code/workshop/pounce`, test with `bench try` (or `rebuild-pounce`), commit, then `bench ship` |

To pull the latest layer + theme + pounce: `haus update` (pulls and rebuilds),
or by hand `nix flake update haus` then rebuild.

## Theme / colors

Colors aren't defined here — the source of truth is the
[nebelung](https://github.com/hausfold/nebelung) flake (whiskers palette +
`name → #hex` map), which `haus` consumes to theme every tool. One palette edit
recolors everything at once. To recolor: edit the palette in
`~/code/workshop/nebelung`, judge it with `bench try switch` (no pushing), then
commit and `bench ship` — it pushes nebelung, ripples the lock updates through
pounce and haus, and updates this repo's lock.

## Pounce dev loop

`rebuild-pounce` (alias in `hosts/mbp`) rebuilds the system against the
**local** `~/code/workshop/pounce` checkout via `--override-input`, so you can
iterate on uncommitted pounce edits. A plain `darwin-rebuild` uses the pinned
GitHub input (reproducible). When happy: commit + push pounce, then `nix flake
update haus`.

## Conventions

- Commits are GPG-signed. Keep messages imperative.
- Never commit secret VALUES. `secretspec.toml` declares which secrets this
  machine needs; the values live in the macOS login keychain (`haus.secrets.provider
  = "keyring"`). `secretspec check` says what's missing, `secretspec set NAME`
  fills one, `secretspec run -- cmd` injects them into just that process.
- `nixfmt` formats `.nix` files.
- Operational gotchas (launchd GUI race, pounce self-signing, Homebrew
  tap-trust, Touch ID + reattach, Determinate GC) live with the code that
  embodies them — see `~/code/workshop/haus/AGENTS.md`.
