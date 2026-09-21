{ username, ... }:

let
  skills = [
    "blast-radius"
    "conflicts"
    "deepen"
    "grill"
    "later"
    "ship"
    "show-me"
    "tracker"
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

    # Two tool skills no agent here invokes, for reasons a better description
    # wouldn't fix: `factory` needs a merge lease this machine doesn't hold,
    # and `scruff`'s verbs are already in ai.instructions. `handoff` is
    # scruff's other skill and is deliberately not named. `pounce` and `trill`
    # stay installed because instructions.md carries the rules that fire them.
    skillExclude = [
      "factory"
      "scruff"
    ];

    instructions = builtins.readFile ./instructions.md;
  };

  haus.keys.leaderExtras = [
    {
      key = "space";
      command = "/etc/profiles/per-user/${username}/bin/pounce run cmd:spawn-agent";
      caption = "Spawn Agent";
    }
    # leader → a: the tracker's one-box add (hosts/mbp/pounce/commands/todo-add.sh).
    # `a` is free of the roster letters (apps.nix), the built-in launch keys and
    # the workspace throws; the windows room asserts as much on every build.
    {
      key = "a";
      command = "/etc/profiles/per-user/${username}/bin/pounce run cmd:todo-add";
      caption = "Add To-do";
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
