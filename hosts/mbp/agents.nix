# Coding agents: which clients exist, what they talk to, and my own skills.
{ username, ... }:

let
  # Installed under BOTH ~/.claude/skills (Claude Code) and ~/.agents/skills
  # (the dir Codex, OpenCode and pi scan). Clients dedupe by frontmatter `name`.
  # `handoff` is deliberately not here — it ships with scruff, and a second
  # definition of that path is an eval conflict rather than a last-wins.
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
    # Codex is deliberately gone. That does NOT cost the bar's Codex usage row:
    # it polls with the OAuth token in ~/.codex/auth.json, which outlives the
    # client — leave that file alone.
    clients = [
      "claude"
      "opencode"
      "pi"
    ];

    # haus's default four minus the todo list.
    pi.packages = [
      "npm:pi-web-access"
      "npm:pi-subagents"
      "npm:@juicesharp/rpiv-ask-user-question"
    ];

    # A loopback proxy serving the Claude Max subscription, so pi and opencode
    # cost what the subscription already costs instead of a metered key. The one
    # hand-held file is ~/.pi/agent/models.json, which points pi's `anthropic`
    # provider at 127.0.0.1:3456 — the room's job ends at "the port answers".
    meridian.enable = true;

    # Name a lane after its task: one request straight at the Messages API
    # (~/.config/scruff/namer-api.sh), ~1s per spawn against the built-in
    # client namer's 8-12s. No ANTHROPIC_API_KEY just means random names again.
    namer = "api";

    # Written once per installed client, so keep it CLIENT-NEUTRAL and
    # universal; repo-specific rules belong in each project's own AGENTS.md.
    instructions = builtins.readFile ./instructions.md;
  };

  # Leader-space → Spawn Agent. `pounce run cmd:<id>`, not the script's own
  # path: `run` goes through the daemon, which is the only place
  # HAUS_REPO_ROOTS and HAUS_LANE_NAMER exist.
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
      # Out-of-store, and the targets are in this repo, which always lives at
      # ~/.config/nix — so editing a SKILL.md is live in the next pane with no
      # rebuild, whichever client that pane runs.
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
          # haus's Claude Code statusline re-rendered through pi's supported
          # custom-footer API, off the same caches — so a CC pane and a pi pane
          # show the same numbers with no binary patch.
          ".pi/agent/extensions/haus-statusline".source = linkHere "hosts/mbp/pi-statusline";
        };
    };
}
