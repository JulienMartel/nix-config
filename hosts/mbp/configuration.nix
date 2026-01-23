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
    delta  # git-delta
    gh
    glow
    gnupg
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
    ];

    brews = [
      "FelixKratz/formulae/sketchybar"
    ];

    casks = [
      "aerospace"
      "cursor"
      "elgato-control-center"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "ghostty"
      "insomnia"
      "jordanbaird-ice"
      "notion-calendar"
      "legcord"
      "raycast"
      "loom"
    ];

    # Note: gcloud-cli requires special handling if needed
    # Can add back if you need it: "google-cloud-sdk"
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
      FXPreferredViewStyle = "Nlsv";  # List view
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    # Keyboard and Menu Bar
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;  # Key repeat instead of character picker
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      AppleShowAllExtensions = true;
      _HIHideMenuBar = true;  # Hide default menu bar (using SketchyBar instead)
    };

    # Trackpad
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  # LaunchAgents for AeroSpace and SketchyBar
  launchd.user.agents = {
    aerospace = {
      serviceConfig = {
        ProgramArguments = [ "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/aerospace.log";
        StandardErrorPath = "/tmp/aerospace.error.log";
      };
    };

    sketchybar = {
      serviceConfig = {
        ProgramArguments = [ "/opt/homebrew/opt/sketchybar/bin/sketchybar" ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/sketchybar.log";
        StandardErrorPath = "/tmp/sketchybar.error.log";
      };
    };
  };

  # Ice menu bar manager settings
  system.activationScripts.postUserActivation.text = ''
    # Ice settings
    defaults write com.jordanbaird.Ice AutoRehide -bool true
    defaults write com.jordanbaird.Ice RehideInterval -int 15
    defaults write com.jordanbaird.Ice ShowOnClick -bool true
    defaults write com.jordanbaird.Ice ShowOnScroll -bool true
    defaults write com.jordanbaird.Ice ShowSectionDividers -bool false
    defaults write com.jordanbaird.Ice HideApplicationMenus -bool true
  '';

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
