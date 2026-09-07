{ pkgs, ... }:

{
  haus.roster = {
    # ---- leader-key apps ----
    zen.order = 50;

    obsidian = {
      order = 20;
      key = "n";
      name = "Obsidian";
      appId = "md.obsidian";
      cask = "obsidian";
    };
    things = {
      order = 30;
      key = "r";
      name = "Things3";
      appId = "com.culturedcode.ThingsMac";
      appStoreId = 904280696;
    };
    slack = {
      order = 40;
      key = "s";
      name = "Slack";
      appId = "com.tinyspeck.slackmacgap";
      cask = "slack";
    };
    claude = {
      order = 80;
      key = "c";
      name = "Claude";
      appId = "com.anthropic.claudefordesktop";
      cask = "claude";
    };
    notion-calendar = {
      order = 90;
      key = "d";
      name = "Notion Calendar";
      appId = "com.cron.electron";
      cask = "notion-calendar";
    };
    passwords = {
      order = 100;
      key = "p";
      name = "Passwords";
    };

    # ---- installed, not launched by keyboard ----
    cap = {
      name = "Cap";
      cask = "cap";
    };
    elgato-control-center = {
      name = "Elgato Control Center";
      cask = "elgato-control-center";
    };
    framer = {
      name = "Framer";
      cask = "framer";
    };
    google-chrome = {
      name = "Google Chrome";
      cask = "google-chrome";
    };
    insomnia = {
      name = "Insomnia";
      cask = "insomnia";
    };
    legcord = {
      name = "Legcord";
      cask = "legcord";
    };
    loom = {
      name = "Loom";
      cask = "loom";
    };
    orbstack = {
      name = "OrbStack";
      package = pkgs.orbstack;
    };
    pear-desktop = {
      name = "Pear Desktop";
      cask = "pear-devs/pear/pear-desktop";
    };
    protonvpn = {
      name = "ProtonVPN";
      cask = "protonvpn";
    };
    qfinder-pro = {
      name = "QFinder Pro";
      cask = "qfinder-pro";
    };
    tailscale = {
      name = "Tailscale";
      cask = "tailscale-app";
    };
    xcode = {
      name = "Xcode";
      appStoreId = 497799835;
    };

    # ---- fonts and CLIs ----
    font-hack.cask = "font-hack-nerd-font";
    font-jetbrains-mono.cask = "font-jetbrains-mono-nerd-font";
    gcloud-cli.cask = "gcloud-cli";
    gogcli.brew = "gogcli";
    ical-buddy.brew = "ical-buddy";
    mas.brew = "mas";
    cloudflared.package = pkgs.cloudflared;

    # ---- system scope ----
    biome = {
      package = pkgs.biome;
      scope = "system";
    };
    bench.package = pkgs.writeShellScriptBin "bench" ''exec "$HOME/code/workshop/bench" "$@"'';
  };

  haus.workspaces = {
    N = {
      key = "n";
      icon = ":obsidian:";
      apps = [ "obsidian" ];
    };
    R = {
      key = "r";
      icon = ":things:";
      apps = [ "things" ];
    };
    S = {
      key = "s";
      icon = ":slack:";
      apps = [ "slack" ];
    };
    C = {
      key = "c";
      icon = ":claude:";
      apps = [ "claude" ];
    };
    D = {
      key = "d";
      icon = ":calendar:";
      apps = [ "notion-calendar" ];
    };
  };

  haus.homebrew = {
    cleanup = "zap";
    upgrade = true;
    autoUpdate = true;
  };

  # Not `homebrew.caskArgs.no_quarantine`: Homebrew 6 dropped that install flag,
  # so caskArgs fails the rebuild's `brew bundle` on the next new cask.
  homebrew.onActivation.extraEnv.HOMEBREW_CASK_OPTS = "--no-quarantine";
}
