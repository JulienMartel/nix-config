# CLAUDE.md

@AGENTS.md

**Project rules go in `AGENTS.md`, never here** — Codex, OpenCode and the rest
never read this file, and would silently run without them. Claude-only wiring:

`.claude/skills/rebuild/SKILL.md` is a symlink into `.agents/skills/` — edit the
target. `.claude/settings.json` is a real file, holding one `SessionStart` hook
that runs `.agents/setup.sh`. The map is
[`.agents/README.md`](./.agents/README.md).

`~/.claude/CLAUDE.md` is generated from `haus.ai.instructions` in
`hosts/mbp/default.nix`, which also merges into `~/.claude/settings.json` on
every rebuild: `claude/auto-mode.json` as `.autoMode` (the `environment` and
`allow` rules the `auto` permission mode's classifier judges against —
`claude auto-mode config` prints the result), `autoMemoryEnabled = false`, and
the permission allowlist, unioned so a grant earned at a prompt is never
dropped. A `/config` toggle of any of them lasts until the next rebuild. The
`WorktreeCreate` / `WorktreeRemove` → `scruff hook create` / `scruff hook
remove` hooks are declared twice — haus's `modules/terminal` and the host file
— and re-asserted every rebuild, so editing one alone does not win.
