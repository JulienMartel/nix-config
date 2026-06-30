{
  config,
  pkgs,
  lib,
  username,
  ...
}:

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
    fnm
    nixfmt
    gemini-cli-bin
    iina
    mdcat
    orbstack
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

  # choose picker settings — single source of truth for the command palette's
  # options. Edit here and rebuild; choose re-reads the file on each open. Schema
  # is intentionally small for now (parsed leniently in pkgs/choose Settings).
  home.file.".config/choose/config.json".text = builtins.toJSON {
    windowMode = "default"; # "default" | "compact"
  };

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
