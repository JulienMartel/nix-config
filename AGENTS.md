# AGENTS.md

One Mac's personal layer (host `mbp`, user `julienmartel`) on the public
[haus](https://github.com/hausfold/haus) desktop: `flake.nix`
(`haus.mkHaus { username; hostname; host; }`) and `hosts/mbp/`, one file per
subject — `default.nix` (identity and this machine's own facts, and it imports
the rest), `apps.nix`, `bar.nix`, `agents.nix`, `claude-code.nix`,
`notifications.nix`, `shell.nix`, `instructions.md`. Anything haus already
defaults to is deliberately absent.
Per-client wiring: [`.agents/README.md`](./.agents/README.md).

## Where does a change go?

**A request for another repo stops before editing** — say where it lives. The
`haus` skill's option reference is the authoritative `haus.*` list.

| You're changing… | Where |
|---|---|
| A personal app (cask or package), this machine only | `hosts/mbp/apps.nix` → `haus.roster` |
| Your identity (git name / email / signing key / org) | `hosts/mbp/default.nix` → `haus.git.*` |
| A personal package or private alias | `hosts/mbp/shell.nix` → `home-manager.users.${username}` |
| The global agent instructions every client reads | `hosts/mbp/instructions.md` |
| A personal skill: `/brief` `/ship` `/park` `/things` `/later` `/unslop` `/wizard` `/grill` `/conflicts` `/deepen` `/blast-radius` `/show-me` | `claude/skills/<name>/SKILL.md`, out-of-store symlinks to `~/.claude/skills/<name>` and `~/.agents/skills/<name>` (one name in `hosts/mbp/agents.nix`'s `skills` list), so an edit is live without a rebuild |
| The desktop: macOS defaults, tiling (`windows`), the bar (`bar`), the shell (`terminal`), Touch ID + firewall (`security`) | `~/code/workshop/haus` |
| Zed's own settings — LSP wiring, fonts, which theme is selected | `~/.config/zed/settings.json`, hand-owned: Zed rewrites it from its own UI, so nix never symlinks it. haus places `themes/nebelung.json` beside it and stops there. `lsp.nixd` there points at `/run/current-system/sw/bin/nixd` and feeds nixd this flake's option set, which is what makes hovering a `haus.*` option show its docs |
| The pounce palette app or its commands | `~/code/workshop/pounce` |
| Colors — the one palette `haus` themes every tool from | `~/code/workshop/nebelung` |

Upstream: edit, `bench try` (`bench try switch` to judge colors), commit,
`bench ship`; `haus update` alone sees a pounce or nebelung change only once
haus's own lock carries it.
`rebuild-pounce` (alias, `hosts/mbp/shell.nix`) rebuilds against the local
pounce checkout via `--override-input`, uncommitted edits included.

## Rebuild (after any change)

`haus rebuild` (`/rebuild` in a pane). Underneath, to read, not to suggest:

```bash
nix build .#darwinConfigurations.mbp.system && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp
```

Build first: a failed build never touches the running system.
**Activation is the user's**: from a worktree, build, then hand over the verb;
`haus` reads `~/.config/nix`, so a worktree needs `HAUS_CONSUMER=<its root>`.
haus's `haus.security.touchId.passwordlessRebuild` writes
`/etc/sudoers.d/darwin-rebuild`, NOPASSWD on
`/run/current-system/sw/bin/{darwin-rebuild,haus-activate}` only — the paths the
verbs take, so the `./result` snippet above still prompts.

## Hand me verbs, never raw nix

*Command vocabulary* in the global instructions applies with force: what you
*say* is the wrapper.

- `bench ship` (`bench ship <repo>` for one repo's downstream), never
  `nix flake update <input>` + commit.
- `haus update`, never `nix flake update haus` + rebuild.
- `haus rebuild` · `bench rebuild` · `bench try [switch]`, never
  `nix build .#darwinConfigurations…` + `darwin-rebuild switch`.
- `haus rollback` / `haus generations`, never `darwin-rebuild --rollback` /
  `--list-generations`.
- `bench status` for what is stale where. `bench` drives the workshop's repos;
  `haus` drives this machine and knows nothing about them.

## Conventions

- Commits are GPG-signed, messages imperative. `nixfmt` formats `.nix`.
- **Never commit a secret value.** `secretspec.toml` declares NAMES only
  (`GITHUB_TOKEN`, `GITHUB_WEBHOOK_SECRET`, `MAIL_IMAP_PASSWORD`, optional
  `ANTHROPIC_API_KEY`); values sit in the login keychain
  (`haus.secrets.provider` defaults to `keyring`), under project
  `haus.secrets.project = "nix"`. `secretspec check` / `secretspec set NAME` /
  `secretspec run -- cmd`. An unused name makes `haus doctor` and a fresh Mac
  ask for it.
- Operational gotchas (launchd, signing, Homebrew, Touch ID, GC) are haus's:
  `~/code/workshop/haus/AGENTS.md`.
