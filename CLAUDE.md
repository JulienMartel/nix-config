# CLAUDE.md

@AGENTS.md

**Project rules go in `AGENTS.md`, never here** — Codex, OpenCode and the rest
never read this file, and would silently run without them. Claude-only wiring:

`.claude/skills/rebuild/SKILL.md` is a symlink into `.agents/skills/` — edit the
target. `.claude/settings.json` is a real file, holding one `SessionStart` hook
that runs `.agents/setup.sh`. The map is
[`.agents/README.md`](./.agents/README.md).

`~/.claude/CLAUDE.md` is generated from `haus.ai.instructions`, whose body is
`hosts/mbp/instructions.md`. `hosts/mbp/claude-code.nix` merges into
`~/.claude/settings.json` on every rebuild: `autoMemoryEnabled = false` and the
permission allowlist, unioned so a grant earned at a prompt is never dropped.
The `autoMode` block the `auto` mode's classifier judges against sits in that
same file as `haus.ai.autoMode`, and haus writes it (`claude auto-mode config`
prints the result). A `/config` toggle of any of them lasts until the next
rebuild. The `WorktreeCreate` / `WorktreeRemove` → `scruff hook create` /
`scruff hook remove` hooks are declared twice — haus's `modules/terminal` and
the host file — and re-asserted every rebuild, so editing one alone does not
win.
