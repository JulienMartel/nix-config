# mbp — Julien's machine. The personal layer on the haus `hacker` desktop:
# identity, hardware facts, and the handful of tastes that differ from haus's
# own defaults. Option reference: `haus skill`, pinned to this build.
{
  imports = [
    ./agents.nix
    ./apps.nix
    ./bar.nix
    ./claude-code.nix
    ./notifications.nix
    ./shell.nix
  ];

  haus = {
    git = {
      name = "Julien Martel";
      email = "julienbmartel@gmail.com";
      org = "hausfold";
      signingKey = "6F7BD6F43A7C1420";
    };

    theme.accent = "pink";
    animations = "fast";

    # Screenshots land in ~/Downloads because CreateDesktop below hides ~/Desktop.
    screenshots.location = "~/Downloads";

    # The Studio Display by UUID, not `main`: docking must not hand the built-in
    # panel a 27" monitor's scale.
    displays."136A50A4-8937-4C6F-B95B-9F1031C62BB3".uiScale = "slightly-larger-text";

    # Closed-display mode always, not just while agents run. `requirePower`
    # stays default, so unplugging is still how I say stop.
    power.lidAwake = {
      enable = true;
      while = "always";
    };

    # This flake's own secretspec project, so the room manifest shares the
    # keychain items already filled in here rather than opening a second set.
    secrets.project = "nix";

    launcher = {
      # Take Fn from macOS at the HID layer: HIToolbox handles Globe inside
      # every process, below the event stream pounce's tap can see, so sharing
      # it opens the stock emoji picker too. Costs Fn's other jobs.
      fnKey = "remap";

      # `exclude` REPLACES pounce's default, so Finder is restated. The rest
      # keep working with no window open — VM, tunnel, mesh, uploads, hotkeys.
      autoQuit = {
        enable = true;
        exclude = [
          "com.apple.finder"
          "dev.kdrag0n.MacVirt"
          "ch.protonvpn.mac"
          "io.tailscale.ipn.macsys"
          "com.google.Chrome"
          "com.cron.electron"
          "com.tinyspeck.slackmacgap"
          "app.legcord.Legcord"
          "so.cap.desktop"
          "com.loom.desktop"
        ];
      };
    };

    terminal = {
      hijackFileAssociations = true;
      ghDash.enable = true;
      # `notes` is the iCloud vault; `ops` is the workshop repo opened as one.
      obsidianVaults = [
        "Library/Mobile Documents/iCloud~md~obsidian/Documents/notes"
        "code/workshop/ops"
      ];
    };

    zen = {
      tabBridge.enable = true;

      # Compiled into Zen's userContent.css — every declaration applies to every
      # document, so a site earns its slug by being one I actually open. Zen has
      # to restart to pick up a rebuild; Gecko reads that file once at startup.
      userStyles = [
        "arch-wiki"
        "bsky"
        "chatgpt"
        "claude"
        "crates.io"
        "deepl"
        "dev.to"
        "devdocs"
        "docs.rs"
        "ghostty.org"
        "github"
        "gmail"
        "go.dev"
        "google-drive"
        "google-gemini"
        "hacker-news"
        "home-manager-options-search"
        "instagram"
        "linkedin"
        "lobste.rs"
        "mdbook"
        "mdn"
        "nixos-manual"
        "nixos-search"
        "npm"
        "perplexity"
        "pypi"
        "react.dev"
        "reddit"
        "regex101"
        "spotify-web"
        "stack-overflow"
        "substack"
        "twitch"
        "twitter"
        "vercel"
        "whatsapp-web"
        "wiki.nixos.org"
        "wikipedia"
        "youtube"
        "zen-browser-docs"
      ];
    };

    snippets = {
      enable = true;
      matches = [
        {
          trigger = "@@";
          replace = "julienbmartel@gmail.com";
        }
        {
          trigger = "##";
          replace = "2044302465";
        }
      ];
    };
  };

  # No desktop icons; files stay in ~/Desktop. Also makes the desktop unclickable.
  system.defaults.finder.CreateDesktop = false;

  # No tap-to-click: palm rests fire stray clicks mid-type.
  system.defaults.trackpad.Clicking = false;
}
