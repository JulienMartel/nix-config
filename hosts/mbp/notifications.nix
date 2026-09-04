# Where a notification comes from and where it goes: trill, mail, GitHub.
{ username, ... }:

let
  # Also the worklist: `trill doctor` and the Silence Native Banners helper
  # audit exactly the bundle ids named here, by exact key.
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
    # MAIL_IMAP_PASSWORD must be a Gmail APP password, not the login one.
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
      # trill verifies GitHub's signature itself, so the secret lived in two
      # hand-kept places and diverged silently: haus kept verifying while trill
      # dropped every delivery as a forgery. `secret` is derived here, never
      # authored. A keychain that won't answer leaves the file alone.
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
      # `resolvers`, and clobbering it disarms every `--until` poller.
      home.activation.trillRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run env MINE=${lib.escapeShellArg (builtins.toJSON trillRules)} \
          ${pkgs.python3}/bin/python3 ${./json-patch.py} rules \
          "$HOME/.config/trill/rules.json" MINE
      '';
    };
}
