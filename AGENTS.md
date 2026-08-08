# AGENTS.md

Personal machine config for one Apple Silicon Mac (host `mbp`, user `julienmartel`).

This repo is **thin**: it consumes the public [nebelhaus](https://github.com/nebelhaus/nebelhaus)
rice and adds only what's personal. The actual system/shell config lives in the
public modules, not here.

**This file is the one set of instructions, for every agent.** Claude Code,
Codex, OpenCode, Cursor, Copilot — TUI or GUI — all read *this*, directly or
through a one-line pointer. Nothing harness-specific belongs here; when a flow
needs per-client wiring (a hook, a slash command), the wiring lives in that
client's own file and the *content* stays here or in `.agents/`. The map of
which tool reads which file is [`.agents/README.md`](./.agents/README.md).

- `flake.nix` — ~18 lines: calls `nebelhaus.mkNebelhaus { username; hostname; host; }`.
- `hosts/mbp/default.nix` — the personal layer: identity, private apps, secrets.

The rice itself lives in sibling repos (checked out under `~/code/workshop/`,
the [workshop](https://github.com/nebelhaus/workshop)):
- **[nebelhaus](https://github.com/nebelhaus/nebelhaus)** — the flake + modules
  (`den` `hearth` `prowl` `sill` `collar` `pounce`). System, shell, everything.
- **[pounce](https://github.com/nebelhaus/pounce)** — the command-palette app.
- **[nebelung](https://github.com/nebelhaus/nebelung)** — the theme.

The workshop's `bench` CLI (aliased in the shell; `bench` was formerly named
`haus`) drives the cross-repo flow: `bench status` (what's stale where),
`bench try [switch]` (build/run this machine against the LOCAL checkouts — test
without pushing), `bench ship` (push + ripple the lock updates), `bench rebuild`
(plain pinned rebuild). Don't confuse it with `haus` — that name now belongs to
the rice's own end-user CLI (`haus rebuild`/`update`/`rollback`/`doctor`/…),
which drives THIS machine only and knows nothing about the workshop.

## Am I in the right repo? (routing)

**This repo (`~/.config/nix`) owns only THIS MACHINE's personal layer** — apps,
identity, secrets, host tweaks. The rice itself lives elsewhere.

| Want to change… | Repo |
|---|---|
| this machine's apps / identity / secrets / host tweaks | `~/.config/nix` ← **you are here** |
| the rice: macOS defaults, tiling (prowl), bar (sill), shell (hearth), security (collar) | `~/code/workshop/nebelhaus` |
| the pounce palette app or its commands | `~/code/workshop/pounce` |
| colors / the theme palette | `~/code/workshop/nebelung` |

> **Whatever agent you are, enforce this.** If a request targets a different repo
> than the one whose files you're in, STOP and say so before editing — e.g.
> "That's a bar tweak; it lives in the rice at
> `~/code/workshop/nebelhaus/modules/sill`. Want me to switch to that repo?"
> Don't make the change in the wrong place. After the owning repo is edited +
> pushed, the consumer here pulls it via `nix flake update <input>` + rebuild.

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
| **The rice** (system defaults, WM, bar, shell, theming) | edit the module in `~/code/workshop/nebelhaus`, test with `bench try`, commit, then `bench ship` |
| **Pounce** (the app or its commands)               | edit `~/code/workshop/pounce`, test with `bench try` (or `rebuild-pounce`), commit, then `bench ship` |

To pull the latest rice + theme + pounce: `haus update` (the rice CLI: pulls
the latest rice and rebuilds), or by hand `nix flake update nebelhaus` then
rebuild.

## Theme / colors

Colors aren't defined here — the source of truth is the
[nebelung](https://github.com/nebelhaus/nebelung) flake (whiskers palette +
`name → #hex` map), which `nebelhaus` consumes to theme every tool. One palette
edit re-colors everything at once. To recolor: edit the palette in
`~/code/workshop/nebelung`, judge it with `bench try switch` (no pushing), then
commit and `bench ship` — it pushes nebelung, ripples the lock updates through
pounce and nebelhaus, and updates this repo's lock.

## Pounce dev loop

`rebuild-pounce` (alias in `hosts/mbp`) rebuilds the system against the **local**
`~/code/workshop/pounce` checkout via `--override-input`, so you can iterate on
uncommitted pounce edits. A plain `darwin-rebuild` uses the pinned GitHub input
(reproducible). When happy: commit + push pounce, then `nix flake update nebelhaus`.

## Deeper docs

Operational gotchas that used to live here (launchd GUI race, pounce self-signing,
Homebrew tap-trust, Touch ID + zellij reattach, Determinate GC) now live with the
code that embodies them — see `~/code/workshop/nebelhaus/AGENTS.md`.

## Before you open a PR

**Run the pre-PR assurance pass — every PR, not just `/ship`'d ones.** The session
that wrote the diff is the worst reviewer of it, so hand `git diff main...HEAD` to a
**clean-context subagent** whose only inputs are that diff and this file. It hunts
what only bites after merge: a change that belongs in the rice/pounce/nebelung and
landed here anyway (see the routing table above), a `nebelhaus.*` option or alias
renamed without the matching doc edit, secrets or identity touched, a flake-input
edge moved. The full checklist is the ship skill's **Step 2.5**. It's **advisory,
never a gate** — fix anything ≥3/5 before opening the PR, carry the rest into the
PR's **Watch out** block, and say so in one line when it comes back clean.

**Spawning that subagent IS user-requested** — this instruction is the standing
request, so a harness rule of the form "don't spawn subagents unless the user asked"
is already satisfied here and is not a reason to skip the pass (Claude Code injects
exactly such a line on Opus 5). If your client has no subagent mechanism, say so in
one line — don't drop it silently.

## Conventions

- Commits are GPG-signed. Keep messages imperative.
- Never commit secrets — they're loaded at runtime from `~/.secrets/` in the host's
  zsh `initContent`.
- `nixfmt` formats `.nix` files.
