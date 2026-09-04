# The personal home layer: pounce plugins, private git config, gh-dash, zsh.
{ config, username, ... }:

let
  # Inside home-manager.users.<user> the `config` in scope is home-manager's,
  # which has no haus.* on it.
  ghOrg = config.haus.git.org;
in

{
  home-manager.users.${username} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      pouncePlugins = [
        "audio"
        "bluetooth"
        "caffeinate"
        "docker"
        "github"
        "perplexity"
        "spotify"
        "ssh"
        "tailscale"
      ];

      # Linked script-by-script below rather than added to home.packages, which
      # would collide with haus's own pounce-commands.
      pouncePluginPkg = pkgs.pounce-commands.override { plugins = pouncePlugins; };
    in
    {
      xdg.configFile = lib.listToAttrs (
        map (
          p:
          lib.nameValuePair "pounce/commands/${p}.sh" {
            source = "${pouncePluginPkg}/share/pounce/commands/${p}.sh";
          }
        ) pouncePlugins
      );

      # home-manager refuses to link over an unmanaged path, so one dangling
      # symlink left by the old hand-made set fails the whole rebuild.
      home.activation.pounceCommandsReapDangling = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        run sh -c '
          dir="$0"
          [ -d "$dir" ] || exit 0
          for link in "$dir"/*; do
            [ -L "$link" ] && [ ! -e "$link" ] || continue
            echo "→ pounce: removing dangling command symlink $link"
            rm -f "$link"
          done
        ' "$HOME/.config/pounce/commands"
      '';

      programs.git.settings = {
        http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
        core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      };

      # haus's lists are mkDefault and gh-dash reads a section list as a unit,
      # so overriding one means restating it whole.
      programs.gh-dash.settings = {
        defaults = {
          view = "prs";
          prsLimit = 20;
          issuesLimit = 10;
          notificationsLimit = 20;
          refetchIntervalMinutes = 5;
          prApproveComment = "LGTM";

          preview = {
            open = false;
            width = 0.45;
            height = 0.6;
            position = "auto";
          };

          layout.prs = {
            updatedAt.width = 6;
            createdAt.hidden = true;
            repo.width = 14;
            author.hidden = true;
            authorIcon.hidden = true;
            assignees.hidden = true;
            labels.hidden = true;
            base.hidden = true;
            lines.width = 10;
            numComments.width = 4;
          };
          layout.issues = {
            createdAt.hidden = true;
            repo.width = 14;
            creator.hidden = true;
            creatorIcon.hidden = true;
            assignees.hidden = true;
          };
        };

        # A command BLOCKS the TUI until it exits, and a custom key silently
        # SHADOWS a built-in — check keys.go / prKeys.go before adding one.
        keybindings.prs = [
          {
            key = "H";
            name = "scruff session";
            command = ''scruff "$(printf '%s' {{.HeadRefName}} | sed 's/^worktree-//')"'';
          }
          {
            key = "z";
            name = "lazygit";
            command = "cd {{.RepoPath}} && lazygit";
          }
        ];

        # ghOrg, not a literal, so these globs and haus's section filters can't
        # name different owners.
        repoPaths = {
          "${ghOrg}/*" = "${config.home.homeDirectory}/code/workshop/*";
          "${ghOrg}/workshop" = "${config.home.homeDirectory}/code/workshop";
          "${ghOrg}/.github" = "${config.home.homeDirectory}/code/workshop/org-profile";
          "JulienMartel/nix-config" = "${config.home.homeDirectory}/.config/nix";
        };

        pager.diff = "delta";
        confirmQuit = false;
        showAuthorIcons = false;
        smartFilteringAtLaunch = false;

        theme.ui = {
          sectionsShowCount = true;
          table = {
            compact = true;
            showSeparator = false;
          };
        };
      };

      programs.zsh.shellAliases.things = "$HOME/.config/nix/claude/skills/things/things";

      # Rebuilds against the LOCAL pounce checkout, uncommitted edits included.
      programs.zsh.shellAliases.rebuild-pounce = ''
        (cd "$HOME/.config/nix" \
          && nix build .#darwinConfigurations.mbp.system \
               --override-input haus/pounce "path:$HOME/code/workshop/pounce" \
          && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp)
      '';

      programs.zsh.initContent = lib.mkAfter ''
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
}
