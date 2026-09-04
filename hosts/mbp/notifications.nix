# Where a notification comes from and where it goes: trill, mail, GitHub.
{ username, ... }:

let
  # trill's rules file is the only place that says what happens to a
  # notification, and it is also the worklist: `trill doctor` and the Silence
  # Native Banners helper audit exactly the apps these rules name. So one entry
  # both routes the card and turns Apple's own copy off.
  #
  # `source` is a bundle id spelled as macOS's notification settings spell it —
  # matching lowercases, but the audit looks the id up by exact key.
  # `delivery` is banner | inbox | digest | drop.
  #
  # Anthropic ships two separate bundles and one can't stand in for the other:
  # claude-code is Claude Code's staged macOS app, claudefordesktop the chat
  # client. Both post turn-taking signals, so neither gets inbox or digest.
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
  # Whether haus OWNS the bundle, not whether this Mac draws cards: haus-notify
  # falls back to Apple's banner either way. Pinning it at a fixed
  # /Applications/Trill.app is what makes the Full Disk Access grant survive
  # every version bump.
  haus.notifications.compositor = true;

  # IMAP IDLE push: new mail draws a trill card in seconds, nothing polls. The
  # password is MAIL_IMAP_PASSWORD in the keychain, and it must be a Gmail APP
  # password, not the login one.
  haus.mail = {
    enable = true;
    address = "julienbmartel@gmail.com";
  };

  # GitHub → hooks.hausfold.co → the receiver here → trill's own bridge, byte
  # for byte. haus holds the HMAC secret itself (secretCommand stays at its
  # empty default), reading it through `haus-secret` with its own audit reason.
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
      # trill verifies GitHub's signature itself, which left one secret in two
      # hand-maintained places — and the divergence is silent: haus keeps
      # verifying while trill drops every delivery as a forgery. So `secret` in
      # github.json is DERIVED from the keychain, never authored; `login` and
      # `port` are trill's own and read straight back out. Via $SECRET in the
      # environment, never argv. A keychain that won't answer leaves the file
      # alone rather than blanking the secret.
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

      # Merged, not owned. rules.json also carries `quietHours` and `resolvers`,
      # and a resolver is the only place a command may live — clobbering the
      # file would silently disarm every `--until` poller. The patch keeps every
      # key and rule this machine didn't declare, and appends nix's last so a
      # hand-written rule keeps its priority.
      home.activation.trillRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run env MINE=${lib.escapeShellArg (builtins.toJSON trillRules)} \
          ${pkgs.python3}/bin/python3 ${./json-patch.py} rules \
          "$HOME/.config/trill/rules.json" MINE
      '';
    };
}
