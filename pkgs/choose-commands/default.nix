{ lib, stdenvNoCC, writeShellScriptBin, symlinkJoin, choose }:

let
  # Command registry - add new commands here
  commands = {
    wifi = {
      name = "WiFi";
      description = "Select WiFi Network";
      icon = "wifi";
      script = ./commands/wifi.sh;
    };
    ports = {
      name = "Ports";
      description = "Kill Listening Ports";
      icon = "network";
      script = ../choose/ports;
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
    };
    apps = {
      name = "Applications";
      description = "Launch an application";
      icon = "square.grid.2x2";
      script = ./commands/apps.sh;
    };
  };

  # Generate registry file content (tab-separated: name\tdescription\ticon\tid)
  registryContent = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (id: cmd: "${cmd.name}\t${cmd.description}\t${cmd.icon}\t${id}") commands
  );

  # Wrap each command script with proper PATH
  wrapCommand = id: cmd: writeShellScriptBin "choose-${id}" ''
    export PATH="${choose}/bin:$PATH"
    exec bash ${cmd.script} "$@"
  '';

  # All wrapped command scripts as derivations
  commandScripts = lib.mapAttrsToList wrapCommand commands;

  # Create PATH string containing all command script bin directories
  commandPaths = lib.concatStringsSep ":" (map (drv: "${drv}/bin") commandScripts);

  # The palette script that shows all commands
  paletteScript = writeShellScriptBin "choose-palette" ''
    # Include paths to all choose-* commands and choose itself
    export PATH="${commandPaths}:${choose}/bin:$PATH"

    # Registry is embedded at build time
    REGISTRY='${registryContent}'

    # Show the palette
    selected=$(echo "$REGISTRY" | choose -p "Quick Actions" -i "sparkles")

    if [[ -n "$selected" ]]; then
      # Output format is: action\traw_line
      # Raw line format is: name\tdescription\ticon\tcmd_id
      # So command ID is at field 5 (action + 4 fields from raw line)
      cmd_id=$(echo "$selected" | cut -f5)

      if [[ -n "$cmd_id" ]]; then
        # Execute the selected command
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
