{ username, ... }:

let
  skills = [
    "blast-radius"
    "brief"
    "conflicts"
    "deepen"
    "grill"
    "later"
    "ship"
    "show-me"
    "things"
    "unslop"
    "wizard"
  ];
in

{
  haus.ai = {
    clients = [
      "claude"
      "opencode"
      "pi"
    ];

    pi.packages = [
      "npm:pi-web-access"
      "npm:pi-subagents"
      "npm:@juicesharp/rpiv-ask-user-question"
    ];

    namer = "api";

    instructions = builtins.readFile ./instructions.md;
  };

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
