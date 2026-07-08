# mbp — Julien's machine. The personal layer on top of the nebelhaus rice:
# identity, private apps, secrets. Everything else lives in the public modules.
{
  username,
  pkgs,
  ...
}:

{
  # ---- identity ----
  nebelhaus.git.name = "Julien Martel";
  nebelhaus.git.email = "julienbmartel@gmail.com";
  nebelhaus.git.signingKey = "6F7BD6F43A7C1420";
  nebelhaus.pounce.signingIdentity = "DE2FB6DF7E66864C5F254DACF0AFC1B00685BA5D";

  # The Super-Shift-t "new tab" picker opens on just these instead of all of $HOME.
  nebelhaus.hearth.newTabDirs = [
    "m"
    "code/nebelhaus"
    "code/qnap-mediastack"
    ".config/nix"
  ];

  # Editor: keep the terminal default (hx) for $EDITOR, but open the Nix config
  # folder in Cursor from the palette/bar, and keep the Helix file-association
  # hijack (double-click json/md/ts/… → Helix) that the rice used to force on.
  nebelhaus.hearth.guiEditor = "com.todesktop.230313mzl4w4u92"; # Cursor bundle id
  nebelhaus.hearth.hijackFileAssociations = true;

  # ---- app roster ----
  # My personal launcher: which app owns which AeroSpace workspace + leader key.
  # This ONE list drives the tiling launcher, the SketchyBar pills, and the
  # pounce cheatsheet (the rice ships only a neutral terminal+browser default).
  # Casks stay in homebrew.casks below (so cask = null here — no double-declare);
  # Music/Passwords are system apps, Things is App Store, Swather is a cask.
  nebelhaus.prowl.apps = [
    {
      key = "t";
      name = "Ghostty";
      workspace = "T";
      appId = "com.mitchellh.ghostty";
      barIcon = ":ghostty:";
      label = "Ghostty (Terminal)";
    }
    {
      key = "n";
      name = "Obsidian";
      workspace = "N";
      appId = "md.obsidian";
      barIcon = ":obsidian:";
      label = "Obsidian";
    }
    {
      key = "r";
      name = "Things3";
      workspace = "R";
      appId = "com.culturedcode.ThingsMac";
      barIcon = ":things:";
      label = "Things3";
    }
    {
      key = "s";
      name = "Slack";
      workspace = "S";
      appId = "com.tinyspeck.slackmacgap";
      barIcon = ":slack:";
      label = "Slack";
    }
    {
      key = "b";
      name = "Zen";
      workspace = "B";
      appId = "app.zen-browser.zen";
      barIcon = ":zen_browser:";
      label = "Zen (Browser)";
    }
    {
      key = "m";
      name = "Music";
      workspace = "M";
      appId = "com.apple.Music";
      barIcon = ":music:";
      label = "Music";
    }
    {
      key = "h";
      name = "Swather";
      workspace = "H";
      appId = "com.swather.app";
      # Swather has no app-font glyph — fa-hourglass (U+F254) in the Nerd Font.
      barIcon = builtins.fromJSON ''"\uf254"'';
      label = "Swather";
    }
    {
      key = "c";
      name = "Claude";
      workspace = "C";
      appId = "com.anthropic.claudefordesktop";
      barIcon = ":claude:";
      label = "Claude";
    }
    {
      key = "d";
      name = "Notion Calendar";
      workspace = "D";
      appId = "com.cron.electron";
      barIcon = ":calendar:";
      label = "Notion Calendar";
    }
    {
      key = "p";
      name = "Passwords";
      # Launcher-only: opens/focuses in the current workspace, no pill/auto-assign.
      label = "Passwords";
    }
  ];

  # My personal SketchyBar items (off in the rice default): the agent-pane status
  # paw (fed by the Claude hooks wired below), the Elgato key light toggle, and
  # the Harvest timer pill (reads ~/.config/sketchybar/harvest_secrets.sh).
  nebelhaus.sill.plugins = [
    "agents"
    "elgato"
    "harvest"
  ];

  # Claude Code's global memory (~/.claude/CLAUDE.md) — how I like to work across
  # every repo. Personal, so it lives here in the host; the rice just provides the
  # nebelhaus.claude.globalMd plumbing (hearth writes the file when set). Keep it
  # short and universal — repo-specific rules belong in each project's own CLAUDE.md.
  nebelhaus.claude.globalMd = ''
    # CLAUDE.md — global

    Personal defaults for how I (julienmartel) like to work, across every repo. Kept
    deliberately short and universal — repo-specific detail lives in each project's own
    CLAUDE.md, not here.

    ## Working in a git worktree

    My super+c (`⌘C`) zellij hotkey spawns Claude panes as `claude --worktree`:
    each session gets its own checkout on a `worktree-<name>` branch, branched from the
    repo's local HEAD, living OUTSIDE the repo (under `~/.cache/claude-worktrees/`). The
    `WorktreeCreate`/`WorktreeRemove` hooks are wired globally, so **any** repo I open can
    be worktree'd — not just nebelhaus.

    **Detect it:** `git rev-parse --git-common-dir` points outside your toplevel → you're
    in a linked worktree.

    **Etiquette when you're in a worktree** (i.e. the detection above says you are):
    - Commit on your `worktree-*` branch as usual.
    - Don't merge into `main` yourself, and don't touch the main checkout's files —
      merging is my call, done from the main checkout.
    - When done, tell me the branch name. The worktree dies with the pane; the branch
      survives until merged.

    This etiquette is worktree-specific. Sometimes I open a plain (non-worktree)
    session directly on `main` for a small one-off — usually when no worktrees are
    active. In that mode, working on and committing to `main` directly is fine and
    expected; the "don't touch main" rule only binds when you're actually in a worktree.

    ## How I ship

    **Ship by default, sized to the change — but only in repos I own solo** (my personal
    infra: nebelhaus family, qnap-mediastack, ~/.config/nix, and the like). In shared or
    client repos, default to caution: prepare the change, then ask before pushing.

    In a solo repo:
    - **Small change** (bugfix, typo, config/theme tweak, version bump, docs): commit,
      verify, and ship in the same turn without asking. A verified fix left uncommitted,
      unpushed, or undeployed is a bug, not a finished task.
    - **Big or risky change** (new feature, refactor, anything hard to roll back, anything
      a user could feel break): verify it works, then stop and ask before shipping. Once
      approved, drive it all the way to shipped — don't stop at "the diff is ready."
    - **Releases / user-facing publishes are always gated.** Propose one after shipping
      user-facing changes, but never tag/publish unprompted.
    - When unsure which bucket a change is in, ask.

    ## How I verify

    **Verify by actually running it**, not by eyeballing the diff. Testing in prod is
    acceptable house style for my personal infra — build it, run it, observe the real
    behavior. Prefer a project's own run/verify skill if it has one.

    ## Keeping docs honest

    If you find something in a CLAUDE.md, README, or docs file that's wrong or stale, fix
    it in the same change — don't just work around it. Keep these files short; push detail
    into the matching docs file rather than growing the top-level one.
  '';

  # A system CLI not in den's baseline.
  environment.systemPackages = [ pkgs.biome ];

  # ---- personal apps (den ships ghostty; prowl aerospace; sill sketchybar) ----
  homebrew.taps = [ "pear-devs/pear" ];
  homebrew.brews = [
    "ical-buddy"
    "gogcli"
    "mas" # the CLI only — masApps is intentionally unused (it hangs)
  ];
  homebrew.casks = [
    "cap"
    "claude"
    "cursor"
    "elgato-control-center"
    "font-hack-nerd-font"
    "font-jetbrains-mono-nerd-font"
    "framer"
    "gcloud-cli"
    "google-chrome"
    "insomnia"
    "legcord"
    "loom"
    "notion-calendar"
    "obsidian"
    "pear-devs/pear/pear-desktop"
    "protonvpn"
    "qfinder-pro"
    "slack"
    "tailscale-app"
    "zen"
  ];
  # App Store-only (no cask; mas can't reliably install on modern macOS):
  #   Dropover (1355679052) · Things (904280696) · Xcode (497799835)
  # Install by hand; System Settings → App Store → automatic updates keeps them current.

  # ---- personal home layer: extra packages, private git config, secrets ----
  home-manager.users.${username} =
    { config, lib, pkgs, nebelung, ... }:
    {
      home.packages = with pkgs; [
        claude-code
        gemini-cli-bin
        orbstack

        # The workshop CLI (~/code/nebelhaus): status / try / ship / rebuild
        # for the whole rice family. A real command on PATH (not an alias) so
        # it works from scripts, other shells, and non-interactive contexts;
        # `haus try switch` supersedes rebuild-pounce (it overrides ALL the
        # local checkouts, not just pounce).
        (writeShellScriptBin "haus" ''exec "$HOME/code/nebelhaus/haus" "$@"'')
      ];

      # Dev loop for hacking on pounce: rebuild the system against the LOCAL
      # pounce checkout (picks up uncommitted edits) instead of the pinned
      # github input. Normal `darwin-rebuild` still uses github → reproducible.
      # When happy: commit + push pounce, then a plain rebuild pins the new rev.
      programs.zsh.shellAliases.rebuild-pounce = ''
        (cd "$HOME/.config/nix" \
          && nix build .#darwinConfigurations.mbp.system \
               --override-input nebelhaus/pounce "path:$HOME/code/nebelhaus/pounce" \
          && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp)
      '';

      # Text expansion (the old Raycast "@@" snippet, nix-style). Needs a
      # one-time Accessibility grant in System Settings; a nixpkgs bump that
      # changes espanso's store path may require re-granting.
      services.espanso = {
        enable = true;
        configs.default.show_icon = false; # no menu bar icon
        matches.default.matches = [
          { trigger = "@@"; replace = "julienbmartel@gmail.com"; }
          { trigger = "##"; replace = "2044302465"; }
        ];
      };

      programs.git.settings = {
        http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
        core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      };

      home.file."Library/Application Support/Zen/distribution/policies.json".text = builtins.toJSON {
        policies = {
          ExtensionSettings = {
            "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
              installation_mode = "force_installed";
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
            };
          };
        };
      };

      home.activation.stylusNebelung =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -d "$HOME/Library/Application Support/Zen" ]; then
             echo "→ Stylus (Zen): to apply the nebelung palette to your userstyles, import the generated JSON:"
             echo "    ${nebelung.themes}/stylus/nebelung-stylus.json"
          fi
        '';

      # Obsidian: paint the vault with Nebelung. The theme is a nebelung *port*
      # (a CSS snippet overriding Obsidian's --color-* vars); we DON'T use the
      # Catppuccin community theme — it re-introduces the blue Nebelung strips
      # out, and a snippet can't reliably override a full theme's own rules.
      # So: Default theme + this snippet.
      #
      # The vault lives in iCloud, so we COPY the snippet (a store symlink would
      # sync as a dangling link to other devices) rather than link it. Obsidian
      # owns appearance.json (rewrites it on any settings change), so we don't
      # freeze it — jq patches it in place, idempotently, each rebuild:
      # Default theme, dark mode, snippet enabled. Everything stays writable.
      #
      # Requires the obsidian port to be present in the pinned nebelung input;
      # until `nix flake update nebelung` (in nebelhaus) propagates it, the
      # `-f` guard makes this a no-op instead of a failed rebuild.
      home.activation.obsidianNebelung =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          vault="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes/.obsidian"
          snippet="${nebelung.themes}/obsidian/nebelung.css"
          if [ -d "$vault" ] && [ -f "$snippet" ]; then
            run mkdir -p "$vault/snippets"
            run install -m 0644 "$snippet" "$vault/snippets/nebelung.css"
            app="$vault/appearance.json"
            [ -f "$app" ] || echo '{}' > "$app"
            tmp="$(mktemp)"
            ${pkgs.jq}/bin/jq \
              '.cssTheme = "" | .theme = "obsidian"
               | .enabledCssSnippets = ((.enabledCssSnippets // []) + ["nebelung"] | unique)' \
              "$app" > "$tmp" && run mv "$tmp" "$app"
          fi
        '';

      # Claude Code — reinstate our hooks in settings.json on every rebuild.
      #  • WorktreeCreate/WorktreeRemove: Super-c / `⌘C` (rice: hearth/zellij)
      #    spawns `claude --worktree`; these hand the create/remove off to `haus`
      #    so worktrees land under ~/.cache/claude-worktrees instead of inside the
      #    repo. The haus path is personal (the workshop lives at ~/code/nebelhaus).
      #  • UserPromptSubmit/Notification/Stop/SessionEnd: feed the `agents` bar
      #    paw (nebelhaus.sill.plugins) — each fires agents-hook.sh from inside the
      #    agent's pane, self-reporting its state (working/waiting/idle) + subscribe
      #    target. Personal because it points at the sketchybar plugin path.
      # All of it lives in the host, NOT the generic rice (the rice's pathless
      # claudeCodePermissionMode correctly stays there). Same jq-merge-only-our-keys,
      # never-own-the-file trick — Claude rewrites settings.json as grants/plugins
      # change, so we preserve the rest. jq is pinned from the store because
      # activation runs with a bare PATH.
      home.activation.claudeCodeHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run sh -c '
          settings="$0"
          haus="$1"
          hook="$2"
          mkdir -p "''${settings%/*}"
          tmp="$settings.hm-seed"
          if [ -s "$settings" ]; then base="$settings"; else base="$tmp.base"; printf "{}" > "$base"; fi
          ${pkgs.jq}/bin/jq \
            ".hooks.WorktreeCreate = [{hooks:[{type:\"command\",command:\"''${haus} wt-create\"}]}]
             | .hooks.WorktreeRemove = [{hooks:[{type:\"command\",command:\"''${haus} wt-remove\"}]}]
             | .hooks.UserPromptSubmit = [{hooks:[{type:\"command\",command:\"''${hook} working\"}]}]
             | .hooks.Notification = [{hooks:[{type:\"command\",command:\"''${hook} waiting\"}]}]
             | .hooks.Stop = [{hooks:[{type:\"command\",command:\"''${hook} idle\"}]}]
             | .hooks.SessionEnd = [{hooks:[{type:\"command\",command:\"''${hook} remove\"}]}]" \
            "$base" > "$tmp"
          mv "$tmp" "$settings"
          rm -f "$tmp.base"
        ' "$HOME/.claude/settings.json" "$HOME/code/nebelhaus/haus" "$HOME/.config/sketchybar/plugins/agents-hook.sh"
      '';

      # Secrets + tooling that shouldn't live in the public rice.
      programs.zsh.initContent = lib.mkAfter ''
        export GEMINI_API_KEY="$(cat ~/.secrets/google-api-key)"
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
}
