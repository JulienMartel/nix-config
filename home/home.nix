{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  # Yazi preview pane: pipe code/text through `bat` (via the piper plugin) so
  # previews match the catppuccin-themed `cat` alias — syntax colours + line
  # numbers. piper supplies $w (pane width) and $1 (file path) to the shell.
  batPreviewer = ''piper -- bat --color=always --paging=never --style=numbers --tabs=2 --terminal-width=$w "$1"'';
in

{
  # Static environment variables (dynamic ones that need shell evaluation
  # like $(tty) or $(cat ...) live in programs.zsh.initContent below)
  home.sessionVariables = {
    CLICOLOR = "1";
    HOMEBREW_NO_ENV_HINTS = "1";
  };

  # User packages
  home.packages = with pkgs; [
    bun
    choose
    choose-commands
    claude-code
    opencode
    fnm
    nixfmt
    gemini-cli-bin
    glow # markdown renderer; yazi's glow previewer shells out to it
    iina
    mdcat
    orbstack
    fd # fast file finder; used by yazi/zoxide navigation
  ];

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      cat = "bat --style=header,grid --tabs=2";
      ls = "lsd";
      lg = "lazygit";
    };

    history = {
      size = 5000;
      save = 5000;
      ignoreDups = true;
      ignoreSpace = true;
      path = "$HOME/.zsh_history";
    };

    historySubstringSearch.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "command-not-found"
      ];
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Dynamic env vars (need shell evaluation, can't use home.sessionVariables)
        export GPG_TTY=$(tty)
        export GEMINI_API_KEY="$(cat ~/.secrets/google-api-key)"

        # Homebrew (Apple Silicon)
        eval "$(/opt/homebrew/bin/brew shellenv)"

        # OrbStack: docker/orbctl PATH + completions
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '')
      ''
        # Custom completions
        fpath=(~/.zsh-completions $fpath)

        # fnm (Node version manager)
        export PATH="$HOME/.fnm:$PATH"
        eval "$(fnm env --use-on-cd --shell zsh)"

        # Key bindings (emacs mode)
        bindkey -e

        # History options
        setopt appendhistory
        setopt sharehistory
        setopt hist_ignore_space
        setopt hist_ignore_all_dups
        setopt hist_save_no_dups
        setopt hist_ignore_dups
        setopt hist_find_no_dups

        # Completion styling
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu no

        # Auto-name the current zellij tab after the repo whenever you cd. Uses
        # the git-root basename (so subdirs of a repo keep the repo's name), or
        # the plain dir basename outside a repo. Fires only on an interactive cd
        # in the focused pane — so rename-tab always targets the right tab, never
        # a background pane racing at startup.
        if [[ -n "$ZELLIJ" ]]; then
          _zj_name_tab() {
            local root name
            root=$(git rev-parse --show-toplevel 2>/dev/null)
            name=''${''${root:-$PWD}:t}
            command zellij action rename-tab "$name" 2>/dev/null
          }
          autoload -Uz add-zsh-hook
          add-zsh-hook chpwd _zj_name_tab
        fi
      ''
    ];
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      gcloud.disabled = true;
    };
  };

  # Git configuration
  programs.git = {
    enable = true;

    signing = {
      key = "6F7BD6F43A7C1420";
      signByDefault = true;
    };

    settings = {
      user.name = "Julien Martel";
      user.email = "julienbmartel@gmail.com";
      color.ui = "auto";
      http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
      push.autoSetupRemote = true;
      core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      tag.gpgSign = true;
    };
  };

  # Delta (git pager) configuration
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      side-by-side = false;
      line-numbers = true;
      # Syntax theme comes from catppuccin.delta below (driven by catppuccin.flavor).
    };
  };

  # Lazygit (the `lg` alias) - managed here so catppuccin can theme it.
  programs.lazygit.enable = true;

  # lsd (the `ls` alias) - managed here so catppuccin can theme it. Zsh
  # integration is off so it only installs + themes; the `ls` alias stays
  # the manual one in shellAliases above. Flip this on for bonus ll/la/lt
  # aliases (and drop the manual `ls` alias to avoid a conflict).
  programs.lsd.enable = true;
  programs.lsd.enableZshIntegration = false;

  # Bat configuration
  programs.bat = {
    enable = true;
    config = {
      style = "header,grid";
      tabs = "2";
    };
  };

  # Yazi file manager. Customises the preview pane:
  #   - Markdown (.md/.mdx) renders through `glow` (formatted, not raw source)
  #   - other text/code renders through `bat` (piped in via the piper plugin) so
  #     previews match the catppuccin-themed `cat` alias: syntax colours + line
  #     numbers. catppuccin themes both bat and yazi via autoEnable.
  #   - images use ghostty's Kitty graphics protocol automatically — yazi detects
  #     the terminal (TERM_PROGRAM=ghostty) and picks it; no config needed.
  # The three bat rules mirror the exact mimes yazi's built-in code/json
  # previewers claim, so JSON/JS/XML that reports as application/* (not text/*)
  # still routes to bat: text/* covers plain source; */{xml,javascript} covers
  # the application/ variants; application/{json,ndjson} covers JSON.
  # prepend_previewers is evaluated top-down, first match wins, ahead of yazi's
  # built-ins — so the glow rules MUST precede the bat rules, else Markdown (also
  # text/*) would fall through to bat.
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # cd-on-exit shell wrapper name. Pinned to the legacy "yy" (the default while
    # home.stateVersion < "26.05") to silence the migration warning. When we bump
    # stateVersion to 26.05+, the upstream default becomes "y" — either drop this
    # line to adopt "y", or keep it if muscle memory prefers "yy". (Only affects
    # the interactive shell function; the newtab.sh/yazi-shell.sh floats call the
    # `yazi` binary directly, so they're unaffected either way.)
    shellWrapperName = "yy";
    # Show dotfiles/dotfolders in the listing.
    settings.mgr.show_hidden = true;
    # parent | current | preview. Default is [1 4 3]; match the preview column to
    # the current file/dir list so the right pane is the same width as the list
    # you're browsing.
    settings.mgr.ratio = [
      1
      4
      4
    ];
    plugins = {
      # Vendored: nixpkgs' yaziPlugins.glow (and its upstream) still use the
      # pre-26 Lua API and crash on yazi 26.x ("attempt to call a nil value
      # (method 'args')"). Our copy under dotfiles/ ports it to the current API.
      # Revert to pkgs.yaziPlugins.glow once that snapshot is 26-compatible.
      glow = ../dotfiles/yazi/plugins/glow.yazi;
      piper = pkgs.yaziPlugins.piper;
    };
    # Esc closes the peek browser, mirroring q. The Super-y float runs plain
    # `yazi` with close_on_exit, so quitting yazi dismisses the overlay. prepend
    # keeps the rest of the preset keymap; this only overrides Esc in the mgr
    # layer (typing a filter still cancels via Esc in the input layer — only
    # clearing an already-applied filter/selection changes to "quit"). Matches
    # the new-tab picker, which already treats Esc as cancel/quit.
    keymap.mgr.prepend_keymap = [
      {
        on = "<Esc>";
        run = "quit";
        desc = "Close the peek browser";
      }
    ];
    settings.plugin.prepend_previewers = [
      {
        url = "*.md";
        run = "glow";
      }
      {
        url = "*.mdx";
        run = "glow";
      }
      {
        mime = "text/*";
        run = batPreviewer;
      }
      {
        mime = "*/{xml,javascript,x-wine-extension-ini}";
        run = batPreviewer;
      }
      {
        mime = "application/{json,ndjson}";
        run = batPreviewer;
      }
    ];
    # Opening a file (Enter) pages it fullscreen in the same pane, then returns
    # to yazi — this is a reading surface, not an editor. Markdown renders through
    # glow; everything else through the catppuccin-themed bat.
    settings.opener = {
      read = [
        {
          run = ''glow -p "$@"'';
          block = true;
          desc = "glow";
        }
      ];
      pager = [
        {
          run = ''bat --style=full --paging=always "$@"'';
          block = true;
          desc = "bat";
        }
      ];
    };
    # Both open.rules AND prepend_previewers match on `url` (a filename glob) or
    # `mime` — `name` is not a valid key for either (newer yazi dropped it). Using
    # `name` is a hard TOML parse error ("at least one of `url` or `mime` must be
    # specified") that makes yazi throw away this whole config and fall back to
    # preset settings.
    settings.open.rules = [
      {
        url = "*.md";
        use = "read";
      }
      {
        url = "*.mdx";
        use = "read";
      }
      {
        url = "*";
        use = "pager";
      }
    ];
  };

  # zoxide — frecency `cd`, and the `z` jump inside yazi's new-tab / jump pickers.
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Catppuccin theming. `catppuccin.flavor` is the single source of truth -
  # every integration below follows it, so changing the flavor here re-themes
  # all of them at once. (Raw dotfiles nix can't inject into - ghostty/config
  # and zellij/config.kdl - name the flavor manually; keep those in sync.)
  # NOTE: under the new catppuccin/nix model `autoEnable` is what auto-enrolls
  # every port, and `enable` is the global on/off toggle. We keep both true to
  # preserve auto-theming; the explicit per-program enables below are now
  # redundant but kept as documentation of which ports we rely on. zellij stays
  # opted out via its own enable = false.
  catppuccin.autoEnable = true;
  catppuccin.enable = true;
  catppuccin.flavor = "mocha";
  catppuccin.bat.enable = true;
  catppuccin.starship.enable = true;
  catppuccin.delta.enable = true;
  catppuccin.fzf.enable = true;
  catppuccin.lazygit.enable = true;
  catppuccin.lsd.enable = true;
  # Zellij is managed as a raw dotfile (dotfiles/zellij/config.kdl, which already
  # names the catppuccin-mocha built-in theme). Disable the module integration so
  # it doesn't collide with / clobber that file.
  catppuccin.zellij.enable = false;

  # FZF configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Zellij configuration (config.kdl managed as a dotfile below for full KDL control)
  programs.zellij.enable = true;

  # Dotfiles - AeroSpace configuration
  home.file.".config/aerospace/aerospace.toml".source = ../dotfiles/aerospace.toml;
  home.file.".config/aerospace/cap-follow.sh" = {
    source = ../dotfiles/aerospace/cap-follow.sh;
    executable = true;
  };
  home.file.".config/aerospace/resort-windows.sh" = {
    source = ../dotfiles/aerospace/resort-windows.sh;
    executable = true;
  };
  home.file.".config/aerospace/on-wake.sh" = {
    source = ../dotfiles/aerospace/on-wake.sh;
    executable = true;
  };
  home.file.".config/aerospace/launch.sh" = {
    source = ../dotfiles/aerospace/launch.sh;
    executable = true;
  };

  # Dotfiles - SketchyBar configuration
  home.file.".config/sketchybar/sketchybarrc".source = ../dotfiles/sketchybar/sketchybarrc;
  home.file.".config/sketchybar/aerospace-notify.sh".source =
    ../dotfiles/sketchybar/aerospace-notify.sh;
  home.file.".config/sketchybar/plugins" = {
    source = ../dotfiles/sketchybar/plugins;
    recursive = true;
  };

  # Dotfiles - Ghostty configuration
  home.file."Library/Application Support/com.mitchellh.ghostty/config".source =
    ../dotfiles/ghostty/config;

  # Dotfiles - Zellij config, layouts, and launch script
  home.file.".config/zellij/config.kdl".source = ../dotfiles/zellij/config.kdl;
  home.file.".config/zellij/layouts" = {
    source = ../dotfiles/zellij/layouts;
    recursive = true;
  };
  home.file.".config/zellij/launch.sh" = {
    source = ../dotfiles/zellij/launch.sh;
    executable = true;
  };
  # yazi ⇄ zellij glue scripts, launched as floating panes by the Super-Shift-y
  # (jump-to-shell) and Super-t (new-tab picker) keybinds in config.kdl.
  home.file.".config/zellij/yazi-shell.sh" = {
    source = ../dotfiles/zellij/yazi-shell.sh;
    executable = true;
  };
  home.file.".config/zellij/newtab.sh" = {
    source = ../dotfiles/zellij/newtab.sh;
    executable = true;
  };
  # copy_command filter (config.kdl): dedents the message gutter and rejoins
  # hard-wrapped prose on copy, so terminal selections paste cleanly elsewhere.
  home.file.".config/zellij/copy-clean.pl" = {
    source = ../dotfiles/zellij/copy-clean.pl;
    executable = true;
  };
  # Dedicated yazi config for the Super-Shift-t new-tab picker (newtab.sh points
  # YAZI_CONFIG_HOME here) so its Enter=pick / q=cancel keymap stays isolated from
  # the main ~/.config/yazi used by the Super-y peek browser. theme.toml is
  # symlinked to the main config's so the picker inherits catppuccin (single
  # source of truth: catppuccin.flavor). The main theme.toml points syntect at an
  # absolute ~/.config/yazi/Catppuccin-mocha.tmTheme, so sharing just theme.toml
  # is enough — no need to copy the tmTheme.
  home.file.".config/yazi-picker/yazi.toml".source = ../dotfiles/yazi/picker/yazi.toml;
  home.file.".config/yazi-picker/keymap.toml".source = ../dotfiles/yazi/picker/keymap.toml;
  home.file.".config/yazi-picker/theme.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/yazi/theme.toml";

  # choose picker settings — single source of truth for the command palette's
  # options. Edit here and rebuild; choose re-reads the file on each open. Schema
  # is intentionally small for now (parsed leniently in pkgs/choose Settings).
  home.file.".config/choose/config.json".text = builtins.toJSON {
    windowMode = "compact"; # "default" | "compact"
    clipboard = {
      enabled = true;
      maxEntries = 200;
      # Copies from these apps are never recorded (on top of the automatic
      # org.nspasteboard.ConcealedType filter that already drops password copies).
      blacklistBundleIds = [ "com.apple.Passwords" ];
      # Auto-paste a selected entry into the previously-focused app (synthesize
      # ⌘V), Raycast-style. Needs the daemon's Accessibility grant (see the
      # "choose daemon runs from a signed copy" gotcha in CLAUDE.md); falls back
      # to clipboard-only when untrusted.
      autoPaste = true;
    };
  };

  # Free up cmd+space for the choose palette (AeroSpace binds it) by disabling
  # macOS Spotlight's "Show Spotlight search" shortcut (symbolic hotkey 64).
  # Uses -dict-add so only key 64 is touched — other custom hotkeys in
  # AppleSymbolicHotKeys are left intact. Runs as the user (correct prefs domain).
  # Takes effect on next login (symbolic-hotkey changes need a fresh loginwindow);
  # already disabled on the current machine, so this is for fresh-machine parity.
  home.activation.disableSpotlightCmdSpace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add 64 '{ enabled = 0; value = { parameters = ( 32, 49, 1048576 ); type = "standard"; }; }'
    $DRY_RUN_CMD /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
  '';

  # nix-index + comma (run any nix package with ", cmd")
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version
  home.stateVersion = "24.11";
}
