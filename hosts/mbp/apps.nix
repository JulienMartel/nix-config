# What this Mac has, where it lives, and who installs it.
{ pkgs, ... }:

{
  # One list of everything installed. `label` is omitted wherever it would just
  # repeat `name` — haus falls back to `name` for the cheatsheet caption.
  haus.roster = {
    # ---- leader-key apps ----
    # ghostty (t) and zen (b) come from haus; zen only moves in the order.
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
      # Paid: mas can't purchase it. The id records what to re-buy, not an install.
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
    # Launcher-only: opens in the current workspace, no pill, no auto-assign.
    passwords = {
      order = 100;
      key = "p";
      name = "Passwords";
    };

    # ---- installed, not launched by keyboard ----
    # No key. Still declared, or `homebrew.cleanup = "zap"` below reaps it.
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
    # Free, so mas could actually fetch this one.
    xcode = {
      name = "Xcode";
      appStoreId = 497799835;
    };

    # ---- fonts and CLIs ----
    # Claude Code is deliberately absent: haus.ai.clients installs it and
    # agents.nix patches that copy. A second bin/claude would collide.
    font-hack.cask = "font-hack-nerd-font";
    font-jetbrains-mono.cask = "font-jetbrains-mono-nerd-font";
    gcloud-cli.cask = "gcloud-cli";
    gogcli.brew = "gogcli";
    ical-buddy.brew = "ical-buddy";
    # For `mas list` / `mas upgrade` by hand — App Store installs stay manual
    # here (haus.appStore.install off), since mas can't buy a paid app.
    mas.brew = "mas";
    # The webhook bridge's tunnel (notifications.nix). On PATH for the one-time
    # `cloudflared tunnel login`.
    cloudflared.package = pkgs.cloudflared;

    # ---- system scope: on PATH for root, launchd jobs and non-login shells ----
    biome = {
      package = pkgs.biome;
      scope = "system";
    };
    # The workshop CLI as a real command, so scripts and non-interactive shells
    # get it too.
    bench.package = pkgs.writeShellScriptBin "bench" ''exec "$HOME/code/workshop/bench" "$@"'';
  };

  # One app per workspace; each key matches that app's roster `key`.
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
    # Fully declarative: an undeclared cask/brew is uninstalled and zapped.
    cleanup = "zap";
    # Chase upstream latest, accepting less reproducible rebuilds.
    upgrade = true;
    autoUpdate = true;
  };

  # Skip Gatekeeper's first-launch prompt for curated casks. Must be the env
  # var, not `homebrew.caskArgs.no_quarantine`: Homebrew 6 dropped the install
  # flag, so caskArgs fails the rebuild's `brew bundle` on every new cask.
  homebrew.onActivation.extraEnv.HOMEBREW_CASK_OPTS = "--no-quarantine";
}
