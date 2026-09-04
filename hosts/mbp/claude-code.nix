# Claude Code: the patched build, and the half of its settings.json nix owns.
{ username, ... }:

{
  # An overlay, not a home.packages entry: haus.ai.clients already installs
  # pkgs.claude-code, and two builds shipping bin/claude would collide. haus
  # pins the VERSION ahead of nixpkgs in an overlay that runs before this one,
  # so these patches ride on whatever build that is — and fail the build rather
  # than silently no-op when a release reshapes the bundle.
  #
  #  1. declutter-claude-footer.py     drop the permission-mode footer row and
  #                                    the right-hand chip strip
  #  2. statusline-permission-mode.py  emit `permission_mode` in the statusline
  #                                    payload, so the chip tracks shift+tab live
  #  3. claude-bytecode-liveness.py    1 and 2 edit JS bun embeds, but bun runs
  #                                    a JSC bytecode cache compiled from that
  #                                    JS — this drops the cache for exactly
  #                                    those modules and then proves, out of the
  #                                    finished binary, that every edit is live
  #  4. caffeinate shadowed with a no-op on claude's PATH only, so the agent
  #     can't block sleep
  nixpkgs.overlays = [
    (final: prev: {
      claude-code =
        let
          # `prev`, never `final` — overriding a package in terms of itself is
          # infinite recursion, not a patch.
          patchedCC = prev.claude-code.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              prev.python3
              prev.darwin.autoSignDarwinBinariesHook # re-sign the patched Mach-O in fixup
            ];
            # The manifest carries each edit's offset and bytes from the two
            # patch scripts to the liveness check, which must run last.
            postInstall = (old.postInstall or "") + ''
              edits="$NIX_BUILD_TOP/claude-tui-edits.jsonl"
              python3 ${./declutter-claude-footer.py} "$out/bin/.claude-wrapped" "$edits"
              python3 ${./statusline-permission-mode.py} "$out/bin/.claude-wrapped" "$edits"
              python3 ${./claude-bytecode-liveness.py} "$out/bin/.claude-wrapped" "$edits"
            '';
          });
        in
        prev.symlinkJoin {
          name = "claude-code-no-caffeinate";
          paths = [ patchedCC ];
          nativeBuildInputs = [ prev.makeBinaryWrapper ];
          postBuild = ''
            rm "$out/bin/claude"
            makeBinaryWrapper "${patchedCC}/bin/claude" "$out/bin/claude" \
              --inherit-argv0 \
              --prefix PATH : "${prev.writeShellScriptBin "caffeinate" "exit 0"}/bin"
          '';
          # symlinkJoin invents its own empty meta, which would drop the
          # platform list and license haus's ai.clients assertions read — and
          # `version`, which its claude-code floor reads and stands down without.
          inherit (prev.claude-code) meta version;
        };
    })
  ];

  home-manager.users.${username} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Merged, not owned: Claude rewrites this file itself, so everything it or
      # `/config` put there has to survive. The allowlist is UNIONed for the same
      # reason — a grant earned at a prompt is never dropped. Toggling any of
      # these through `/config` lasts only until the next rebuild.
      home.activation.claudeCodePersonal =
        let
          settings = "${config.home.homeDirectory}/.claude/settings.json";
          agentsHook = "${config.home.homeDirectory}/.config/sketchybar/plugins/agents-hook.sh";
          cmd = command: [
            {
              hooks = [
                {
                  type = "command";
                  inherit command;
                }
              ];
            }
          ];
          patch = {
            hooks = {
              # ⌘A's worktrees land under ~/.cache/claude-worktrees, get parked
              # on pane close, and stay resumable. Note the `hook` subcommand.
              WorktreeCreate = cmd "/run/current-system/sw/bin/scruff hook create";
              WorktreeRemove = cmd "/run/current-system/sw/bin/scruff hook remove";
              # Feeds the bar's `agents` paw. Host-side: it names a plugin path.
              UserPromptSubmit = cmd "${agentsHook} working";
              Notification = cmd "${agentsHook} waiting";
              Stop = cmd "${agentsHook} idle";
              SessionEnd = cmd "${agentsHook} remove";
            };
            # New sessions start with tool output collapsed; ⌃O still expands.
            verbose = false;
            # No reads from or writes to ~/.claude/projects/*/memory — the repo
            # is the source of truth. Account-level memory in the Claude apps is
            # a separate, untouched setting.
            autoMemoryEnabled = false;
          };
          allow = [
            "Bash(git:*)"
            "Bash(git worktree:*)"
            "Bash(gh:*)"
            "Bash(bench:*)"
            "Bash(wt:*)"
            "Bash(scruff:*)"
            "Bash(haus:*)"
          ];
          patchWith = args: ''
            run ${pkgs.python3}/bin/python3 ${./json-patch.py} ${args}
          '';
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          patchWith "merge ${settings} ${lib.escapeShellArg (builtins.toJSON patch)}"
          + patchWith "union ${settings} permissions.allow ${lib.escapeShellArg (builtins.toJSON allow)}"
        );
    };
}
