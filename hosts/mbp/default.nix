# mbp — identity and this machine's own facts. Options: `haus skill`.
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

    screenshots.location = "~/Downloads";

    displays."136A50A4-8937-4C6F-B95B-9F1031C62BB3".uiScale = "slightly-larger-text";

    power.lidAwake = {
      enable = true;
      while = "always";
    };

    # Shares this flake's keychain items; the default opens a second set.
    secrets.project = "nix";

    launcher = {
      fnKey = "remap";

      # Replaces pounce's default rather than extending it, so Finder is restated.
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
      obsidianVaults = [
        "Library/Mobile Documents/iCloud~md~obsidian/Documents/notes"
        "code/workshop/ops"
      ];
    };

    zen = {
      tabBridge.enable = true;

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

  system.defaults.finder.CreateDesktop = false;

  system.defaults.trackpad.Clicking = false;
}
