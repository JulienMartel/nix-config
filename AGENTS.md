# AGENTS.md

Personal machine config for one Apple Silicon Mac (host `mbp`, user
`julienmartel`).

This repo is **thin**: it consumes the public
[haus](https://github.com/hausfold/haus) layer and adds only what's personal.
The actual system/shell config lives in the public modules, not here.

- `flake.nix` — 18 lines: calls `haus.mkHaus { username; hostname; host; }`.
- `hosts/mbp/` — the personal layer, one file per subject. `default.nix` holds
  identity and the machine's own facts and imports the rest:

  | File | Owns |
  |---|---|
  | `default.nix` | identity, display, power, trackpad, launcher, zen, snippets |
  | `apps.nix` | the roster, workspaces, Homebrew policy |
  | `bar.nix` | both bars |
  | `agents.nix` | `haus.ai.*`, my skills, the pi statusline |
  | `instructions.md` | `haus.ai.instructions` — the global agent instructions every client on this machine reads |
  | `claude-code.nix` | the patched Claude Code overlay and its `settings.json` merge |
  | `notifications.nix` | trill rules, mail, the GitHub webhook bridge |
  | `shell.nix` | pounce plugins, private git config, gh-dash, zsh |

  Anything haus already defaults to is deliberately absent — `haus skill` is the
  option reference, pinned to this machine's build.

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
> the consumer here catches up via `bench ship` (it ripples every stale lock
> edge down the chain — `bench ship <repo>` for just one repo's downstream) or
> `haus update` (which pulls and rebuilds — but only sees a pounce/nebelung
> change once haus's own lock carries it, so the ripple is `bench ship`'s
> job). Never suggest a hand-run `nix flake update <input>` for this — see
> **Hand me verbs, never raw nix** below.

## Rebuild (after any change)

The verb is `haus rebuild` (or `/rebuild` in a Claude pane; `bench rebuild`
from the workshop is the same pinned rebuild) — that is what you run and what
you tell me to run. Under the hood it is:

```bash
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Build first, switch second — a failed build never touches the running system;
the raw pipeline is documentation of what the verb does, not a thing to hand
me. Nix errors are verbose; read from the *bottom* up for the actual cause.

`switch` doesn't prompt for a password: `/etc/sudoers.d/darwin-rebuild` grants
`NOPASSWD` for the `darwin-rebuild` store path only. That file is **hand-managed
on purpose** — a nix-managed sudoers file with a syntax error wedges all of sudo,
and you'd need sudo to rebuild the fix. Don't move it into this repo. If the
prompt comes back, the store path changed shape: re-check the glob against
`readlink -f /run/current-system/sw/bin/darwin-rebuild`.

## Deliberately not in this repo

Things installed on `mbp` by hand, so nothing here declares them:

| What | Where | Why it stays out |
|---|---|---|
| passwordless `darwin-rebuild` | `/etc/sudoers.d/darwin-rebuild` | lockout risk (above) |

Don't propose folding it into `hosts/mbp/default.nix` unless asked.

meridian used to be on that list and no longer is: it's a haus room
(`haus.ai.meridian.enable`, set in `hosts/mbp/agents.nix`), and its activation
boots out the old hand-installed `co.hausfold.meridian` agent. `pi` is a haus
client (`haus.ai.clients`), not a hand-install either.

## Where does a change go?

| You're changing… | Do this |
|---|---|
| A personal app (cask/brew), for this machine only | `hosts/mbp/apps.nix` → `haus.roster` |
| Your identity (git name/email/signing) | `hosts/mbp/default.nix` → `haus.git.*` |
| A personal package / secret / private alias | `hosts/mbp/shell.nix` → `home-manager.users.${username}` |
| The global agent instructions every client reads | `hosts/mbp/instructions.md` |
| **The layer** (system defaults, WM, bar, shell, theming) | edit the module in `~/code/workshop/haus`, test with `bench try`, commit, then `bench ship` |
| **Pounce** (the app or its commands) | edit `~/code/workshop/pounce`, test with `bench try` (or `rebuild-pounce`), commit, then `bench ship` |

To pull the latest layer + theme + pounce: `haus update` (pulls and rebuilds).
That it is `nix flake update haus` + rebuild underneath is for reading the
code, not for suggesting — the verb also reports what actually changed.

## Hand me verbs, never raw nix

Every routine operation here has a wrapper that carries its guards, and the
wrapper's name is what goes in any command you hand me — a numbered step, a
"Need from you" block, a wrap-up line. This is about what you *say*, not just
what you run: a report that ends "run `nix flake update pounce` in haus, then
`nix flake update haus` here + rebuild" is wrong even if every word is
technically true — that whole ripple is one `bench ship`.

| don't suggest | say instead |
|---|---|
| `nix flake update <input>` + commit, in any family repo | `bench ship` — or `bench ship <repo>` for one repo's downstream ripple |
| `nix flake update haus` here + rebuild | `haus update` |
| `nix build .#darwinConfigurations…` + `darwin-rebuild switch` | `haus rebuild` (this machine) · `bench rebuild` (same, from the workshop) · `bench try [switch]` (against local checkouts) |
| `darwin-rebuild --rollback` / `--list-generations` | `haus rollback` / `haus generations` |
| `git pull` per family checkout | `bench pull [repo…]` |
| `git stash` in a worktree | `scruff park` / `scruff unpark` |

Raw `nix` / `darwin-rebuild` appears in a suggestion only when no wrapper
covers the operation — and then say so ("no wrapper for this"). For a **haus
user who is not a contributor** (no `~/code/workshop`), the `haus` CLI is the
entire vocabulary: if a step has no `haus` verb, that is a missing verb to
report as a gap, never a licence to hand them nix.

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
iterate on uncommitted pounce edits. A plain rebuild uses the pinned
GitHub input (reproducible). When happy: commit pounce, then `bench ship
pounce` — it pushes pounce and ripples the lock through haus into this repo.

## Conventions

- Commits are GPG-signed. Keep messages imperative.
- Never commit secret VALUES. `secretspec.toml` declares NAMES only
  (`GITHUB_TOKEN`, `GITHUB_WEBHOOK_SECRET`, optional `ANTHROPIC_API_KEY`);
  values live in the macOS login keychain (`haus.secrets.provider = "keyring"`).
  `secretspec check` says what's missing, `secretspec set NAME` fills one,
  `secretspec run -- cmd` injects them into just that process. Don't declare one
  speculatively: an unused NAME makes `haus doctor` and a fresh-Mac setup ask for
  a key nobody uses.
- `nixfmt` formats `.nix` files.
- Operational gotchas (launchd GUI race, pounce self-signing, Homebrew
  tap-trust, Touch ID + reattach, Determinate GC) live with the code that
  embodies them — see `~/code/workshop/haus/AGENTS.md`.
