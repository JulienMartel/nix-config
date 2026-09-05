# Claude Code: the patched build, and the half of its settings.json nix owns.
{ username, ... }:

{
  # An overlay, not a home.packages entry: haus.ai.clients already installs
  # pkgs.claude-code, and two builds shipping bin/claude would collide.
  nixpkgs.overlays = [
    (final: prev: {
      claude-code =
        let
          # `prev`, never `final` — overriding a package in terms of itself is
          # infinite recursion, not a patch.
          patchedCC = prev.claude-code.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              prev.python3
              prev.darwin.autoSignDarwinBinariesHook
            ];
            # The first two edit JS bun embeds; bun runs a bytecode cache
            # compiled from that JS, so the liveness check drops the cache for
            # those modules and proves the edits are live. It must run last —
            # the manifest carries each edit's offset from the other two.
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
          # caffeinate shadowed on claude's PATH only, so the agent can't block
          # sleep. Everything else still gets /usr/bin/caffeinate.
          postBuild = ''
            rm "$out/bin/claude"
            makeBinaryWrapper "${patchedCC}/bin/claude" "$out/bin/claude" \
              --inherit-argv0 \
              --prefix PATH : "${prev.writeShellScriptBin "caffeinate" "exit 0"}/bin"
          '';
          # symlinkJoin invents an empty meta, which would drop the platforms,
          # license and version that haus's ai.clients assertions read.
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
      # Merged, never written whole: Claude rewrites this file itself. The
      # allowlist is UNIONed for the same reason — a grant earned at a prompt is
      # never dropped. Toggling any of this via `/config` lasts until the next
      # rebuild.
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
              WorktreeCreate = cmd "/run/current-system/sw/bin/scruff hook create";
              WorktreeRemove = cmd "/run/current-system/sw/bin/scruff hook remove";
              UserPromptSubmit = cmd "${agentsHook} working";
              Notification = cmd "${agentsHook} waiting";
              Stop = cmd "${agentsHook} idle";
              SessionEnd = cmd "${agentsHook} remove";
            };
            verbose = false;
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
