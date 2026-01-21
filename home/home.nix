{ config, pkgs, lib, ... }:

{
  # Note: home.username and home.homeDirectory are set automatically
  # by nix-darwin's home-manager module

  # User packages
  home.packages = with pkgs; [
    fnm
  ];

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      cat = "bat --style=header,grid --theme=ansi --tabs=2";
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

    # Use initContent with lib.mkBefore for early initialization
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Environment variables (early init)
        export CLICOLOR=1
        export GPG_TTY=$(tty)

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

        # Zinit installation and setup
        if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
            print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
            command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
            command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
                print -P "%F{33} %F{34}Installation successful.%f%b" || \
                print -P "%F{160} The clone has failed.%f%b"
        fi
        source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
        autoload -Uz _zinit
        (( ''${+_comps} )) && _comps[zinit]=_zinit

        # Zinit annexes
        zinit light-mode for \
            zdharma-continuum/zinit-annex-as-monitor \
            zdharma-continuum/zinit-annex-bin-gem-node \
            zdharma-continuum/zinit-annex-patch-dl \
            zdharma-continuum/zinit-annex-rust

        # Zinit plugins
        zinit light zsh-users/zsh-syntax-highlighting
        zinit light zsh-users/zsh-completions
        zinit light zsh-users/zsh-autosuggestions
        zinit light Aloxaf/fzf-tab

        # Oh-My-Zsh snippets
        zinit snippet OMZP::git
        zinit snippet OMZP::sudo
        zinit snippet OMZP::command-not-found

        # Load completions
        autoload -Uz compinit && compinit

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
        export PATH=/Users/julienmartel/.opencode/bin:$PATH

        # Antigravity
        export PATH="/Users/julienmartel/.antigravity/antigravity/bin:$PATH"
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
      http.cookiefile = "/Users/julienmartel/.gitcookies";
      push.autoSetupRemote = true;
      core.attributesfile = "/Users/julienmartel/.gitattributes_global";
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
      theme = "ansi";
      style = "header,grid";
      tabs = "2";
    };
  };

  # FZF configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Dotfiles - AeroSpace configuration
  home.file.".config/aerospace/aerospace.toml".source = ../dotfiles/aerospace.toml;

  # Dotfiles - SketchyBar configuration
  home.file.".config/sketchybar/sketchybarrc".source = ../dotfiles/sketchybar/sketchybarrc;
  home.file.".config/sketchybar/aerospace-notify.sh".source = ../dotfiles/sketchybar/aerospace-notify.sh;
  home.file.".config/sketchybar/plugins" = {
    source = ../dotfiles/sketchybar/plugins;
    recursive = true;
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home Manager state version
  home.stateVersion = "24.11";
}
