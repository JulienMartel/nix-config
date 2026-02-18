{ pkgs, username, ... }:

{
  # Primary user for user-specific settings (required by nix-darwin)
  system.primaryUser = username;

  # Enable zsh system-wide (handles Homebrew PATH automatically)
  programs.zsh.enable = true;

  # System packages (CLI tools migrated from Homebrew)
  environment.systemPackages = with pkgs; [
    # Core CLI tools
    bat
    fzf
    delta # git-delta
    gh
    glow
    gnupg
    jq
    lazygit
    lsd
    neofetch
    tree
    ttyd

    # Development tools
    biome
  ];

  # Homebrew - declaratively managed GUI apps (casks)
  homebrew = {
    enable = true;

    # Automatically remove unlisted packages
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };

    taps = [
      "nikitabobko/tap"
      "FelixKratz/formulae"
      "pear-devs/pear"
    ];

    brews = [
      "FelixKratz/formulae/sketchybar"
      "ical-buddy"
      "gogcli"
      "mas" # Mac App Store CLI
    ];

    casks = [
      "aerospace"
      "beeper"
      "cursor"
      "elgato-control-center"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "ghostty"
      "insomnia"
      "jordanbaird-ice"
      "notion-calendar"
      "legcord"
      "obsidian"
      "pear-devs/pear/pear-desktop"
      "raycast"
      "loom"
      "zen"
      "google-cloud-sdk"
    ];

    # Mac App Store apps (use `mas search <app>` to find IDs)
    masApps = {
      "Slack" = 803453959;
      "Harvest" = 506189836;
      "Dropover" = 1355679052;
      "Things" = 904280696;
      "Xcode" = 497799835;
    };
  };

  # macOS system settings
  system.defaults = {
    # Dock
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false;
      orientation = "bottom";
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "Nlsv"; # List view
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    # Keyboard and Menu Bar
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false; # Key repeat instead of character picker
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      AppleShowAllExtensions = true;
      _HIHideMenuBar = true; # Hide default menu bar (using SketchyBar instead)
    };

    # Trackpad
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  # Choose daemon - persistent background process for instant command palette
  launchd.user.agents.choose = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.choose}/Applications/Choose.app/Contents/MacOS/choose"
        "--daemon"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/tmp/choose.out.log";
      StandardErrorPath = "/tmp/choose.err.log";
      EnvironmentVariables = {
        LANG = "en_US.UTF-8";
        HOME = "/Users/${username}";
      };
    };
  };

  # SketchyBar - launch via nix-darwin instead of brew services
  launchd.user.agents.sketchybar = {
    serviceConfig = {
      ProgramArguments = [ "/opt/homebrew/opt/sketchybar/bin/sketchybar" ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/tmp/sketchybar.out.log";
      StandardErrorPath = "/tmp/sketchybar.err.log";
      EnvironmentVariables = {
        LANG = "en_US.UTF-8";
        PATH = "/run/current-system/sw/bin:/etc/profiles/per-user/${username}/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  # Enable Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Disable nix-darwin's Nix management (using Determinate installer)
  nix.enable = false;

  # Note: nix.settings and nix.gc are managed by Determinate installer
  # To configure garbage collection, use: sudo nix-collect-garbage -d

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Required for nix-darwin
  system.stateVersion = 5;

  # The platform the configuration will be used on
  nixpkgs.hostPlatform = "aarch64-darwin";
}
