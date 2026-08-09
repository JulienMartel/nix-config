# `.agents/` — the harness-neutral layer

Every coding agent invents its own dotfile. This directory is the answer to
that: **the content lives here (or in `AGENTS.md`), and each client's own
directory holds nothing but wiring** — a pointer, a symlink, or a hook
registration. Switch harness, keep the flows.

> **One body, many pointers.** A rule, a flow, or a script is written *once*. If
> a file under `.claude/`, `.codex/`, `.opencode/` or `.github/` carries a
> project rule rather than a reference to one, it's a bug — the next agent, on a
> different client, runs without it.

Corollary: never "fix" a stale pointer by copying the current text into it.

The family-wide rationale — the four kinds of agent config, how to add a new
harness — is written once, in the workshop:
[`hausfold/workshop` → `.agents/README.md`](https://github.com/hausfold/workshop/blob/main/.agents/README.md).
The table below is only what's wired in *this* repo.

| Path | Read by | What it actually is |
|---|---|---|
| `AGENTS.md` | Codex, OpenCode, Cursor, Zed, Amp, Copilot-in-editor, and anything else that speaks [agents.md](https://agents.md) | **The source of truth.** Every rule for this machine's config, starting with the routing rule that keeps rice changes out of here. |
| `CLAUDE.md` | Claude Code (CLI, desktop, web) | `@AGENTS.md` import + a table of Claude-only wiring. Claude Code reads only `CLAUDE.md`, so the import is how it gets the real file. |
| `GEMINI.md` | Gemini CLI | Symlink → `AGENTS.md`. |
| `opencode.json` | OpenCode | Names `AGENTS.md` explicitly. Belt and braces — OpenCode finds it anyway. |
| `.github/copilot-instructions.md` | GitHub Copilot coding agent + code review | A **real file**, not a symlink: Copilot reads through the GitHub API, where a symlink is just a path string. |
| `.agents/skills/rebuild/SKILL.md` | Codex (scans project `.agents/skills/`), and every other client via the links below | The `/rebuild` flow: build, then switch, and how to read a Nix error when it fails. Was `.claude/commands/rebuild.md`, where only one client could reach it. |
| `.claude/skills/rebuild/SKILL.md` | Claude Code | Symlink → `.agents/skills/rebuild/SKILL.md`. |
| `.opencode/skills/rebuild` | OpenCode | Symlink → `.agents/skills/rebuild`. |
| `.opencode/commands/rebuild.md` | OpenCode | Four-line command that says "read the shared body and follow it" — guarantees `/rebuild` exists even if skill discovery doesn't fire. |
| `.agents/setup.sh` | all of them, via the hooks below | Installs Determinate Nix in a bare cloud container, persists `PATH` + `NIX_SSL_CERT_FILE`. No-ops on macOS and where Nix already exists. Replaces the old Claude-only `.claude/hooks/session-start.sh`. |
| `.claude/settings.json` | Claude Code | `SessionStart` → `.agents/setup.sh`. |
| `.codex/hooks.json` + `.codex/config.toml` | Codex CLI | `SessionStart` → `.agents/setup.sh`, plus the flag that enables hooks. |
| `.opencode/plugins/nix-bootstrap.js` | OpenCode | Plugin load *is* session start; runs the same script, swallowing every error. |

**Deliberately not in this layer:** `.claude/settings.local.json`. It's a
pre-approved tool-call allowlist — machine-local permission state, not a project
rule — so it stays exactly where its client expects it, and other clients keep
their own.

**Also not here: the `haus` skill.** `~/.claude/skills/haus/` is
installed by the rice (`haus.claude.skill`) and generated from the revision
this machine pins, so it can't drift from what's actually settable. It's outside
this repo entirely — but the files are ordinary markdown, so read them whatever
client you are.

## Caveats

- **A cloud session can evaluate but never activate.** `darwin-rebuild` is
  macOS-only; switching is always this machine's own job, at its keyboard.
- **Codex repo-local hooks** have historically not fired in every interactive
  session ([openai/codex#17532](https://github.com/openai/codex/issues/17532)),
  and some builds want an absolute path for `hooks`. If `/hooks` doesn't list
  ours, point your own `~/.codex/config.toml` at this repo's `.codex/hooks.json`.
- **Codex cloud takes its setup script from the web UI**, not from a file here;
  set it to `bash .agents/setup.sh`.
- **The OpenCode plugin is best-effort** and deliberately silent: it runs the
  bootstrap on plugin load and swallows failures. A bootstrap that breaks the
  client would be worse than none.
- **Whatever the harness, the fallback is the same:** `./.agents/setup.sh` is
  idempotent and safe to run by hand. If a flake command says Nix is missing,
  that's the fix.
