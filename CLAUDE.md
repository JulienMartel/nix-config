# CLAUDE.md

@AGENTS.md

<!--
Everything above this line is imported from AGENTS.md — the one set of project
instructions, shared by every harness. Put project rules THERE, not here, or
Codex/OpenCode/Copilot silently run without them.

Only Claude-specific wiring belongs below.
-->

## Claude-specific wiring (nothing project-level here)

| Thing | Where | Notes |
|---|---|---|
| Project instructions | `AGENTS.md`, imported above | Claude Code reads only `CLAUDE.md`, so this file exists purely to import it. The *global* instructions (`~/.claude/CLAUDE.md`) are generated from `haus.ai.instructions` in `hosts/mbp/default.nix` — a different file, edited there. |
| `/rebuild` | `.claude/skills/rebuild/SKILL.md` | Symlink into `.agents/skills/rebuild/` — the shared body every client uses. Edit the target, never the link. |
| Session bootstrap | `.claude/settings.json` → `SessionStart` → `.agents/setup.sh` | Same script Codex and OpenCode call. Installs Nix in cloud containers, no-ops locally. |
| Permission allowlist | `.claude/settings.local.json` | Genuinely Claude-only and machine-local: it lists pre-approved tool calls, not project rules. Untracked equivalents in other clients stay theirs. |
| Worktree hooks | `~/.claude/settings.json` (yours, not the repo's) → `holt hook create` / `holt hook remove` | Claude owns and rewrites that file, so haus merges these two keys in at activation. Self-healing; not hand-edited here. |
| My global skills — `/brief`, `/ship`, `/park`, `/handoff`, `/things` | `claude/skills/<name>/SKILL.md`, wired in `hosts/mbp/default.nix` | This repo's, installed to `~/.claude/skills/<name>` **and** `~/.agents/skills/<name>` (the dir Codex and OpenCode scan) as **out-of-store** symlinks, so editing `SKILL.md` is live in the next pane with no rebuild, whichever client that pane runs. Personal answer-shape and workflow, not haus features — that's why they're here and not in `haus`. |
| The `haus` skill | `~/.claude/skills/haus/` (+ `~/.codex/skills/`, `~/.config/opencode/skills/`) | Not in this repo — installed by haus (`haus.ai.skill`), once per client, generated from the revision this machine pins. Its option reference is the authoritative list of `haus.*`. |

The full cross-harness map is [`.agents/README.md`](./.agents/README.md).
