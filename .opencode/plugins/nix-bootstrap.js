/**
 * OpenCode's half of the shared session bootstrap.
 *
 * Every harness runs the same script — `.agents/setup.sh` — to install Nix in a
 * bare cloud container (see `.agents/README.md`). Claude Code and Codex have
 * SessionStart hooks; OpenCode's equivalent is a plugin, which loads once when
 * the session starts, so the factory body IS the session-start hook.
 *
 * Deliberately unfailing: a bootstrap that breaks the client is worse than no
 * bootstrap. The script itself is idempotent and no-ops on macOS.
 */
export const NixBootstrap = async ({ directory, $ }) => {
  try {
    if (process.platform !== "darwin") {
      const root = directory ?? process.cwd()
      await $`bash ${root}/.agents/setup.sh`.quiet().nothrow()
    }
  } catch {
    // Nothing to do: the agent can always run ./.agents/setup.sh by hand.
  }
  return {}
}
