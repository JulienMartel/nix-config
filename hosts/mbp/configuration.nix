{ pkgs, username, ... }:

let
  # Wrap a GUI agent's launch so that:
  #   1. The launcher itself does NOT live in /nix/store. Determinate Nix
  #      mounts /nix from a separate APFS volume, and at cold boot the
  #      user-domain launchd evaluates plists before that volume is
  #      reliably available -- the kernel reports "Missing executable"
  #      and the job is parked with last exit = 78 (EX_CONFIG). We embed
  #      the script inline so it lives in the plist itself (on the boot
  #      volume in ~/Library/LaunchAgents).
  #   2. We wait until the GUI session is actually ready before exec'ing.
  #      Aqua-session limit alone isn't enough; AeroSpace's Carbon hotkey
  #      registration silently no-ops if the event manager isn't up.
  withGUIWait = target: [
    "/bin/bash"
    "-c"
    ''
      until /usr/bin/pgrep -x Dock >/dev/null 2>&1; do sleep 1; done
      until /usr/bin/pgrep -x Finder >/dev/null 2>&1; do sleep 1; done
      until /usr/bin/pgrep -x SystemUIServer >/dev/null 2>&1; do sleep 1; done
      deadline=$(( $(date +%s) + 60 ))
      until /usr/bin/osascript -e 'tell application "System Events" to count processes' >/dev/null 2>&1; do
        [ "$(date +%s)" -gt "$deadline" ] && break
        sleep 1
      done
      sleep 5
      exec "$0"
    ''
    target
  ];

  # Self-signing launch wrapper for the choose daemon. The daemon needs a STABLE
  # code-signing identity so a macOS Accessibility (TCC) grant survives `choose`
  # rebuilds (the store path's adhoc cdhash changes every build, losing any grant
  # keyed to it). The nix build sandbox can't reach the login keychain, so we sign
  # impurely here, in the user's Aqua session, against a stable writable copy:
  #   - copy Choose.app out of the (mutable) store path to a fixed location,
  #   - codesign it with the Apple Development identity already in the keychain
  #     (stable designated requirement -> TCC grant persists across rebuilds),
  #   - exec the daemon from that signed copy.
  # The marker file records which store path the copy was signed from, so we only
  # re-copy/re-sign when `choose` actually changed. Exec'ing via /bin/bash (boot
  # volume) also sidesteps the cold-boot exit-78 race that plagues store-path
  # executables (see withGUIWait above). If signing fails we fall back to the
  # unsigned store binary so the palette keeps working (just without Accessibility).
  chooseSignIdentity = "DE2FB6DF7E66864C5F254DACF0AFC1B00685BA5D"; # Apple Development: JULIEN BERNARD MARTEL (6NGM8QR7J9)
  chooseDaemonLaunch = [
    "/bin/bash"
    "-c"
    ''
      # Wait for the GUI session (and thus the /nix volume + an unlocked login
      # keychain) before touching the store path or codesign.
      until /usr/bin/pgrep -x Dock >/dev/null 2>&1; do sleep 1; done
      until /usr/bin/pgrep -x Finder >/dev/null 2>&1; do sleep 1; done
      until /usr/bin/pgrep -x SystemUIServer >/dev/null 2>&1; do sleep 1; done

      STORE_APP="${pkgs.choose}/Applications/Choose.app"
      STATE_DIR="$HOME/.local/state/choose"
      DEST="$STATE_DIR/Choose.app"
      MARKER="$STATE_DIR/.signed-from"

      if [ ! -d "$DEST" ] || [ "$(/bin/cat "$MARKER" 2>/dev/null)" != "$STORE_APP" ]; then
        /bin/mkdir -p "$STATE_DIR"
        /bin/rm -rf "$DEST"
        if /bin/cp -R "$STORE_APP" "$DEST" \
           && /bin/chmod -R u+w "$DEST" \
           && /usr/bin/codesign --force --identifier com.local.choose -s "${chooseSignIdentity}" "$DEST"; then
          /usr/bin/printf '%s' "$STORE_APP" > "$MARKER"
        else
          echo "choose: codesign failed, falling back to unsigned store binary (no Accessibility)" >&2
          /bin/rm -f "$MARKER"
          exec "$STORE_APP/Contents/MacOS/choose" --daemon
        fi
      fi
      exec "$DEST/Contents/MacOS/choose" --daemon
    ''
  ];

  # Hyper key: remap Caps Lock -> F18 (pure hidutil, native to macOS) so AeroSpace
  # can use F18 as the trigger for its `launch` leader mode. Set to false and
  # rebuild to disable the remap (caps reverts to plain Caps Lock and the leader
  # is unavailable).
  useNativeHyper = true;
in
{
  # Primary user for user-specific settings (required by nix-darwin)
  system.primaryUser = username;

  # Caps Lock -> F18, feeding AeroSpace's `launch` leader mode (see
  # useNativeHyper above). Decimal values are the hidutil HID usage codes.
  system.keyboard.enableKeyMapping = useNativeHyper;
  system.keyboard.userKeyMapping =
    if useNativeHyper then
      [
        {
          HIDKeyboardModifierMappingSrc = 30064771129; # 0x700000039 caps lock
          HIDKeyboardModifierMappingDst = 30064771181; # 0x70000006D F18
        }
      ]
    else
      [ ];

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
    fastfetch
    tree
    ttyd

    # Development tools
    biome
  ];

  # Fonts managed by nix (linked into /Library/Fonts). sketchybar-app-font is a
  # ligature font: setting an item's icon to a token like `:ghostty:` renders
  # that app's logo — used for the workspace pill glyphs in sketchybarrc.
  fonts.packages = [ pkgs.sketchybar-app-font ];

  # Homebrew - declaratively managed GUI apps (casks)
  homebrew = {
    enable = true;

    # Automatically remove unlisted packages
    onActivation = {
      autoUpdate = true;
      upgrade = true;
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
      "cap"
      "claude"
      "cursor"
      "elgato-control-center"
      "figma"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "framer"
      "gcloud-cli"
      "ghostty"
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

    # App Store-only apps (no Homebrew cask exists, and `mas` can't reliably
    # install/upgrade on modern macOS — it hangs). Install these manually from
    # the App Store and enable App Store automatic updates to keep them current:
    #   - Dropover  (1355679052)
    #   - Things    (904280696)
    #   - Xcode     (497799835)
    # masApps is intentionally omitted so `onActivation.upgrade` never invokes mas.
  };

  # With `onActivation.upgrade`, brew loads each cask to check for updates, which
  # triggers Homebrew's tap-trust check on our third-party taps (nikitabobko,
  # FelixKratz, pear-devs). That check is flaky under the sudo-driven activation
  # (the per-user trust store at ~/.homebrew/trust.json gets bypassed/invalidated),
  # making `darwin-rebuild switch` fail with "Refusing to load cask ... from
  # untrusted tap". We curate these taps ourselves, so disable the requirement
  # globally via a brew.env file that `bin/brew` reads on every invocation. /etc is
  # set up before the Homebrew bundle step, so this applies on the same rebuild.
  environment.etc."homebrew/brew.env".text = ''
    HOMEBREW_NO_REQUIRE_TAP_TRUST=1
  '';

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

    # Auto-update App Store apps (keeps App Store-only apps like Things,
    # Dropover, and Xcode current now that masApps is no longer managed).
    CustomUserPreferences."com.apple.commerce".AutoUpdate = true;
  };

  # Choose daemon - persistent background process for instant command palette.
  # Launched via the self-signing wrapper (see chooseDaemonLaunch above) so the
  # daemon runs from a stably-signed copy and can hold an Accessibility grant.
  launchd.user.agents.choose = {
    serviceConfig = {
      ProgramArguments = chooseDaemonLaunch;
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

  # AeroSpace - launch via nix-darwin instead of relying on macOS Login Items
  launchd.user.agents.aerospace = {
    serviceConfig = {
      ProgramArguments = withGUIWait "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/tmp/aerospace.out.log";
      StandardErrorPath = "/tmp/aerospace.err.log";
      EnvironmentVariables = {
        LANG = "en_US.UTF-8";
        PATH = "/run/current-system/sw/bin:/etc/profiles/per-user/${username}/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  # sleepwatcher - on wake, re-sort AeroSpace windows back to their assigned
  # workspaces (macOS otherwise dumps them all on the current workspace).
  launchd.user.agents.sleepwatcher = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.sleepwatcher}/bin/sleepwatcher"
        "-w"
        "/Users/${username}/.config/aerospace/on-wake.sh"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/sleepwatcher.out.log";
      StandardErrorPath = "/tmp/sleepwatcher.err.log";
      EnvironmentVariables = {
        PATH = "/run/current-system/sw/bin:/etc/profiles/per-user/${username}/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  # SketchyBar - launch via nix-darwin instead of brew services
  launchd.user.agents.sketchybar = {
    serviceConfig = {
      ProgramArguments = withGUIWait "/opt/homebrew/opt/sketchybar/bin/sketchybar";
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

  # Periodic Nix GC. Determinate's daemon only GCs reactively when disk is
  # tight (min-free/max-free) -- on a large SSD that effectively never fires,
  # so generations accumulate forever. Run our own weekly cleanup instead.
  launchd.daemons.nix-gc = {
    serviceConfig = {
      ProgramArguments = [
        "/nix/var/nix/profiles/default/bin/nix-collect-garbage"
        "--delete-older-than"
        "30d"
      ];
      StartCalendarInterval = [
        {
          Weekday = 0; # Sunday
          Hour = 3;
          Minute = 0;
        }
      ];
      StandardOutPath = "/var/log/nix-gc.out.log";
      StandardErrorPath = "/var/log/nix-gc.err.log";
    };
  };

  # Touch ID for sudo. `reattach` is REQUIRED here because we run sudo inside
  # zellij: a terminal multiplexer detaches the process from the GUI (Aqua)
  # session, so pam_tid.so can't reach the Touch ID UI and the prompt beachballs/
  # wedges. pam_reattach.so (inserted before pam_tid by this option) reattaches
  # the auth to the GUI session and fixes the hang. Falls back to the in-terminal
  # password prompt if Touch ID is cancelled.
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # nix.settings and the daemon itself are managed by the Determinate installer
  # (see /etc/nix/nix.custom.conf), so nix-darwin's nix module is disabled.
  nix.enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Required for nix-darwin
  system.stateVersion = 5;

  # The platform the configuration will be used on
  nixpkgs.hostPlatform = "aarch64-darwin";
}
