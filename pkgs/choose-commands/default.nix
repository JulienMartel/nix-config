{
  lib,
  stdenvNoCC,
  writeShellScriptBin,
  symlinkJoin,
  choose,
}:

let
  # Command registry - add new commands here
  commands = {
    wifi = {
      name = "WiFi";
      description = "Select WiFi Network";
      icon = "wifi";
      script = ./commands/wifi.sh;
      submenu = true;
    };
    ports = {
      name = "Ports";
      description = "Kill Listening Ports";
      icon = "network";
      script = ../choose/ports;
      submenu = true;
    };
    rebuild = {
      name = "Rebuild System";
      description = "Rebuild nix configuration";
      icon = "arrow.triangle.2.circlepath";
      script = ./commands/rebuild.sh;
    };
    reload-bar = {
      name = "Reload SketchyBar";
      description = "Reload bar configuration";
      icon = "arrow.clockwise";
      script = ./commands/reload-bar.sh;
    };
    reload-aerospace = {
      name = "Reload AeroSpace";
      description = "Reload AeroSpace configuration";
      icon = "rectangle.3.group";
      script = ./commands/reload-aerospace.sh;
    };
    nix-config = {
      name = "Nix Config";
      description = "Open in editor";
      icon = "snowflake";
      script = ./commands/nix-config.sh;
    };
    preferences = {
      name = "System Settings";
      description = "Open macOS Settings";
      icon = "gear";
      script = ./commands/preferences.sh;
    };
    activity = {
      name = "Activity Monitor";
      description = "View system processes";
      icon = "chart.bar";
      script = ./commands/activity.sh;
    };
    force-quit = {
      name = "Force Quit";
      description = "Force quit a running app";
      icon = "xmark.octagon";
      script = ./commands/force-quit.sh;
      submenu = true;
    };
    screenshots = {
      name = "Screenshots";
      description = "Browse & copy recent screenshots";
      icon = "photo.on.rectangle";
      script = ./commands/screenshots.sh;
      submenu = true;
    };
    clipboard = {
      name = "Clipboard History";
      description = "Browse & paste recent copies";
      icon = "doc.on.clipboard";
      script = ./commands/clipboard.sh;
      submenu = true;
    };
    emoji = {
      name = "Emoji";
      description = "Search & copy emoji";
      icon = "face.smiling";
      script = ./commands/emoji.sh;
      submenu = true;
    };
    lock = {
      name = "Lock Screen";
      description = "Lock the display";
      icon = "lock";
      script = ./commands/lock.sh;
    };
    brew-services = {
      name = "Brew Services";
      description = "Start/Stop/Restart services";
      icon = "shippingbox";
      script = ./commands/brew-services.sh;
      submenu = true;
    };
  };

  # Generate registry file content (tab-separated):
  #   name \t description \t icon \t id \t submenu(1|0)
  # submenu=1 marks a two-step command (it re-invokes choose), so the daemon
  # keeps the window up with a loading state instead of fading between steps.
  registryContent = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      id: cmd:
      "${cmd.name}\t${cmd.description}\t${cmd.icon}\t${id}\t${if cmd.submenu or false then "1" else "0"}"
    ) commands
  );

  # Wrap each command script with proper PATH
  wrapCommand =
    id: cmd:
    writeShellScriptBin "choose-${id}" ''
      export PATH="${choose}/bin:$PATH"
      exec bash ${cmd.script} "$@"
    '';

  # All wrapped command scripts as derivations
  commandScripts = lib.mapAttrsToList wrapCommand commands;

  # Create PATH string containing all command script bin directories
  commandPaths = lib.concatStringsSep ":" (map (drv: "${drv}/bin") commandScripts);

  # The palette script: launcher mode merges these commands with installed apps.
  # `choose` enumerates /Applications natively and launches apps itself, so the
  # only thing returned to this script is a selected command ("run\t<id>").
  paletteScript = writeShellScriptBin "choose-palette" ''
    # Include paths to all choose-* commands and choose itself
    export PATH="${commandPaths}:${choose}/bin:$PATH"

    # Command registry is embedded at build time (name\tdescription\ticon\tid).
    REGISTRY='${registryContent}'

    # Launcher mode: apps are added natively; empty query shows the top 7.
    selected=$(echo "$REGISTRY" | choose --launcher --max-empty 7 -p "Search apps & actions..." -i "magnifyingglass")

    # App launches are handled inside choose; a command selection comes back as
    # "run\t<id>". Anything else (empty) means dismissed or an app was opened.
    if [[ -n "$selected" ]]; then
      cmd_id=$(echo "$selected" | cut -f2)
      if [[ -n "$cmd_id" ]]; then
        exec choose-"$cmd_id"
      fi
    fi
  '';

in
symlinkJoin {
  name = "choose-commands";
  paths = commandScripts ++ [ paletteScript ];

  meta = {
    description = "Command palette and choose-based utilities";
    platforms = lib.platforms.darwin;
  };
}
