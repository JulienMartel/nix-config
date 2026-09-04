{ username, ... }:

let
  trillRules = [
    {
      match.source = "com.apple.SoftwareUpdateNotification";
      delivery = "banner";
    }
    {
      match.source = "com.anthropic.claude-code";
      delivery = "banner";
    }
    {
      match.source = "com.anthropic.claudefordesktop";
      delivery = "banner";
    }
  ];
in

{
  haus.notifications.compositor = true;

  haus.mail = {
    enable = true;
    address = "julienbmartel@gmail.com";
  };

  haus.github = {
    enable = true;
    forwardTo = [ "127.0.0.1:42787" ];
    backstop = 1800;
    hooks = [ { scope = "org:hausfold"; } ];
    tunnel = {
      enable = true;
      id = "6209f5f4-f8a2-4501-8af9-a8bb24777a89";
      hostname = "hooks.hausfold.co";
    };
  };

  home-manager.users.${username} =
    { lib, pkgs, ... }:
    {
      home.activation.trillGithubSecret = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run sh -c '
          config="$0"
          py="$1"
          spec="$2"
          SECRET=$(${pkgs.secretspec}/bin/secretspec get --file "$spec" \
            --reason "sync trill'"'"'s copy of the hausfold org webhook secret" \
            GITHUB_WEBHOOK_SECRET 2>/dev/null) || SECRET=""
          if [ -z "$SECRET" ]; then
            echo "trill: no GITHUB_WEBHOOK_SECRET from the keychain — leaving $config alone" >&2
            exit 0
          fi
          export SECRET
          "$py" ${./json-patch.py} set-env "$config" secret SECRET
        ' "$HOME/.config/trill/github.json" "${pkgs.python3}/bin/python3" "$HOME/.config/nix/secretspec.toml"
      '';

      # Merged, never written whole: rules.json also carries `quietHours` and
      # `resolvers`, which a plain write would drop.
      home.activation.trillRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run env MINE=${lib.escapeShellArg (builtins.toJSON trillRules)} \
          ${pkgs.python3}/bin/python3 ${./json-patch.py} rules \
          "$HOME/.config/trill/rules.json" MINE
      '';
    };
}
