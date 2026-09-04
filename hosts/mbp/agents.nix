# Coding agents: clients, what they talk to, and my own skills.
{ username, ... }:

let
  # `handoff` is deliberately absent — it ships with scruff, and a second
  # definition of that path is an eval conflict, not a last-wins.
  skills = [
    "blast-radius"
    "brief"
    "conflicts"
    "deepen"
    "grill"
    "later"
    "park"
    "ship"
    "things"
    "unslop"
    "wizard"
  ];
in

{
  haus.ai = {
    # Codex is gone, but the bar's Codex usage row still polls the OAuth token
    # in ~/.codex/auth.json — deleting that file is what would kill the row.
    clients = [
      "claude"
      "opencode"
      "pi"
    ];

    # haus's default four, minus the todo list.
    pi.packages = [
      "npm:pi-web-access"
      "npm:pi-subagents"
      "npm:@juicesharp/rpiv-ask-user-question"
    ];

    # ~/.pi/agent/models.json is hand-held and points pi's `anthropic` provider
    # at this port. Dropping it puts pi back on a metered key.
    meridian.enable = true;

    namer = "api";

    instructions = builtins.readFile ./instructions.md;
  };

  # `pounce run cmd:<id>` goes through the daemon, the only place
  # HAUS_REPO_ROOTS and HAUS_LANE_NAMER exist. Exec'ing the script drops both.
  haus.keys.leaderExtras = [
    {
      key = "space";
      command = "/etc/profiles/per-user/${username}/bin/pounce run cmd:spawn-agent";
      caption = "Spawn Agent";
    }
  ];

  home-manager.users.${username} =
    { config, lib, ... }:
    let
      linkHere =
        path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/${path}";
      skillLink = name: { source = linkHere "claude/skills/${name}"; };
    in
    {
      home.file =
        lib.listToAttrs (
          lib.concatMap (name: [
            (lib.nameValuePair ".claude/skills/${name}" (skillLink name))
            (lib.nameValuePair ".agents/skills/${name}" (skillLink name))
          ]) skills
        )
        // {
          ".pi/agent/extensions/haus-statusline".source = linkHere "hosts/mbp/pi-statusline";
        };
    };
}
