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
    antigravity
    choose
    choose-commands
    claude-code
    fnm
    nixfmt
    gemini-cli-bin
    iina
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
      '')
      ''
        # Custom completions
        fpath=(~/.zsh-completions $fpath)

        # Cargo
        [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

        # fnm (Node version manager)
        export PATH="$HOME/.fnm:$PATH"
        eval "$(fnm env --use-on-cd --shell zsh)"

        # Bun
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

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

        # uv (Python package manager)
        [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

        # opencode
        export PATH="$HOME/.opencode/bin:$PATH"
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
      syntax-theme = "catppuccin-mocha";
    };
  };

  # Bat configuration
  programs.bat = {
    enable = true;
    config = {
      style = "header,grid";
      tabs = "2";
    };
  };

  # Catppuccin theming (new module API)
  catppuccin.bat.enable = true;
  catppuccin.starship.enable = true;
  catppuccin.flavor = "mocha";

  # FZF configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Zellij configuration
  programs.zellij = {
    enable = true;
    settings = {
      pane_frames = false;
      serialize_pane_viewport = true;
      theme = "catppuccin-mocha";
      # Using built-in default layout which has bars
      # default_layout = "custom";
      scroll_buffer_size = 50000;
      show_release_notes = false;
      show_startup_tips = false;
    };
  };

  # Dotfiles - AeroSpace configuration
  home.file.".config/aerospace/aerospace.toml".source = ../dotfiles/aerospace.toml;
  home.file.".config/aerospace/cap-follow.sh" = {
    source = ../dotfiles/aerospace/cap-follow.sh;
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

  # Dotfiles - Zellij layouts (config managed by programs.zellij)
  home.file.".config/zellij/layouts" = {
    source = ../dotfiles/zellij/layouts;
    recursive = true;
  };

  # Ice menu bar manager settings
  home.activation.iceSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/defaults write com.jordanbaird.Ice AutoRehide -bool true
    /usr/bin/defaults write com.jordanbaird.Ice RehideInterval -int 15
    /usr/bin/defaults write com.jordanbaird.Ice ShowOnClick -bool true
    /usr/bin/defaults write com.jordanbaird.Ice ShowOnScroll -bool true
    /usr/bin/defaults write com.jordanbaird.Ice ShowSectionDividers -bool false
    /usr/bin/defaults write com.jordanbaird.Ice HideApplicationMenus -bool true
  '';

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version
  home.stateVersion = "24.11";
}
