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
| Project instructions | `AGENTS.md`, imported above | Claude Code reads only `CLAUDE.md`, so this file exists purely to import it. |
| `/rebuild` | `.claude/skills/rebuild/SKILL.md` | Symlink into `.agents/skills/rebuild/` — the shared body every client uses. Edit the target, never the link. Was `.claude/commands/rebuild.md`. |
| Session bootstrap | `.claude/settings.json` → `SessionStart` → `.agents/setup.sh` | Same script Codex and OpenCode call. Installs Nix in cloud containers, no-ops locally. |
| Permission allowlist | `.claude/settings.local.json` | Genuinely Claude-only and machine-local: it lists pre-approved tool calls, not project rules. Untracked equivalents in other clients stay theirs. |
| Worktree hooks | `~/.claude/settings.json` (yours, not the repo's) → `wt create` / `wt remove` | Claude owns that file and rewrites it, so no repo touches it. |
| The nebelhaus skill | `~/.claude/skills/nebelhaus/` | Not in this repo — installed by the rice (`nebelhaus.claude.skill`), generated from the revision this machine pins. Its option reference is the authoritative list of `nebelhaus.*`. |

The full cross-harness map is [`.agents/README.md`](./.agents/README.md).
