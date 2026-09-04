# The personal home layer: pounce plugins, private git config, gh-dash, zsh.
{ config, username, ... }:

let
  # Bound out here because inside home-manager.users.<user> the `config` in
  # scope is home-manager's, which has no haus.* on it.
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
      # pounce's optional command plugins ship off; this list is the switch.
      # Their CLI deps already come from haus.
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

      # Symlinked script-by-script below rather than added to home.packages,
      # which would collide with haus's own pounce-commands.
      pouncePluginPkg = pkgs.pounce-commands.override { plugins = pouncePlugins; };
    in
    {
      # Into ~/.config/pounce/commands, pounce's highest-precedence runtime dir.
      # xdg.configFile, not home.file: a dynamic attrset can't merge with the
      # static home.file attr-paths elsewhere in this host.
      xdg.configFile = lib.listToAttrs (
        map (
          p:
          lib.nameValuePair "pounce/commands/${p}.sh" {
            source = "${pouncePluginPkg}/share/pounce/commands/${p}.sh";
          }
        ) pouncePlugins
      );

      # home-manager refuses to link over an unmanaged path, so a leftover
      # dangling symlink from the old hand-made set fails the rebuild. Runs
      # before checkLinkTargets, and only ever removes BROKEN links.
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

      # My half of gh-dash: checkout paths, keys and a laptop's column widths.
      # haus's lists are mkDefault, so overriding one means restating it whole —
      # gh-dash reads a section list as a unit.
      programs.gh-dash.settings = {
        defaults = {
          view = "prs";
          prsLimit = 20;
          issuesLimit = 10;
          notificationsLimit = 20;
          refetchIntervalMinutes = 5;
          prApproveComment = "LGTM";

          # Off by default: on a laptop the preview eats half the width. `p`
          # toggles it when the CI detail is what you're after.
          preview = {
            open = false;
            width = 0.45;
            height = 0.6;
            position = "auto";
          };

          # Hide what's constant in a solo org (author, base) or that I never
          # act on, and let `title` take the slack.
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

        # Commands BLOCK the TUI until they exit, so only things worth taking
        # over the pane — never `bench try`. Custom keys silently SHADOW
        # built-ins, so check keys.go / prKeys.go before adding one.
        keybindings.prs = [
          {
            # scruff names the worktree after the branch minus `worktree-`.
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

        # Where my checkouts sit — the half haus can't know. Exact keys beat the
        # wildcard. ghOrg, not a literal, so these globs and haus's section
        # filters can't name different owners.
        repoPaths = {
          "${ghOrg}/*" = "${config.home.homeDirectory}/code/workshop/*";
          "${ghOrg}/workshop" = "${config.home.homeDirectory}/code/workshop";
          "${ghOrg}/.github" = "${config.home.homeDirectory}/code/workshop/org-profile";
          "JulienMartel/nix-config" = "${config.home.homeDirectory}/.config/nix";
        };

        pager.diff = "delta";
        confirmQuit = false;
        showAuthorIcons = false;
        # Open on the dashboard, not a filter prompt.
        smartFilteringAtLaunch = false;

        theme.ui = {
          sectionsShowCount = true;
          table = {
            compact = true;
            showSeparator = false;
          };
        };
      };

      # An alias rather than a PATH entry: the script is a thin wrapper living
      # in this repo, so it should follow the checkout, not get copied to the store.
      programs.zsh.shellAliases.things = "$HOME/.config/nix/claude/skills/things/things";

      # Dev loop for hacking on pounce: rebuild against the LOCAL checkout
      # (uncommitted edits) instead of the pinned input.
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
