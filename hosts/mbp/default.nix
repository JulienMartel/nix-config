# mbp — Julien's machine. The personal layer on top of the haus desktop:
# identity, private apps, secrets. Everything else lives in the public modules.
{
  config,
  username,
  pkgs,
  ...
}:

let
  # Bound here because inside `home-manager.users.<user>` the `config` in scope
  # is home-manager's, which has no haus.* on it. Lets repoPaths (this
  # machine's checkout layout) reuse the org name instead of repeating it.
  ghOrg = config.haus.git.org;

  # ---- trill's rules ----
  # trill's rules file is the ONLY place that says what happens to a
  # notification, and since 2026-08-25 it is also the worklist: `trill doctor`
  # and the Silence Native Banners helper audit exactly the apps these rules
  # name (`NotificationSettingsAudit.listedBundleIDs`). So a rule here does two
  # jobs — it decides where the card goes, and it puts that app in the
  # walkthrough that turns Apple's own banner off. One entry, both halves.
  #
  # `source` is a bundle id as it appears in macOS's own notification settings,
  # case and all: matching lowercases both sides, but the audit looks the id up
  # in Apple's store by exact key. `delivery` is banner | inbox | digest | drop.
  #
  # System Settings itself never posts anything — measured: there is no
  # `com.apple.systempreferences` row anywhere in usernoted's store. The update
  # nags that *look* like System Settings come from
  # `com.apple.SoftwareUpdateNotification`, which on this Mac is set to
  # PERSISTENT alerts, i.e. the ones that sit there until clicked. That is the
  # one worth taking over first.
  #
  # These are appended after anything hand-written in rules.json, so a rule
  # typed into the file still wins — first match wins, and nix's are last.
  # Anthropic ships TWO bundles here and they are separate apps, so they need
  # separate rules — one id can't stand in for the other:
  #
  #   com.anthropic.claude-code        Claude Code's macOS app. Read off
  #                                    ~/Library/Application Support/Claude/
  #                                    claude-code/<version>/claude.app, where
  #                                    Claude.app stages it.
  #   com.anthropic.claudefordesktop   the chat client, /Applications/Claude.app.
  #
  # Both post the same *kind* of thing, which is why both get `banner` and
  # neither gets inbox or digest. Measured 2026-08-25, every card the chat app
  # has ever drawn on this Mac reads "Claude is waiting for your input" — a
  # turn-taking signal, same as Claude Code's permission prompts and
  # end-of-run pings. Held for a digest flush it arrives too late to be one.
  #
  # The mirror already banners apps no rule names, so what these buy is a
  # *named* source: `trill doctor` and the Silence Native Banners helper audit
  # exactly the sources rules.json lists, so listing them is what turns
  # Apple's own copy off before the pair is ever drawn twice.
  #
  # One caveat, and it only applies to the Code entry: measured the same day,
  # `com.anthropic.claude-code` is in NEITHER usernoted's store NOR ncprefs,
  # because the staged bundle has never been launched here — Claude Code runs
  # as the CLI in Ghostty on this Mac. That rule is armed rather than active,
  # and the first banner it routes is the first one the app ever posts. The
  # chat app's is live today.
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
  # ---- identity ----
  haus.git.name = "Julien Martel";
  haus.git.email = "julienbmartel@gmail.com";
  haus.git.signingKey = "6F7BD6F43A7C1420";
  # By SHA, not name, so the generated launch-agent script doesn't carry my
  # legal name. Refresh with `security find-identity -v -p codesigning`.
  haus.launcher.signingIdentity = "4D2693E75A214534ACE299861AE7FC3086573136";

  # The Fn/Globe key opens pounce's emoji grid (haus wires that by default). Take
  # the key away from macOS at the HID layer instead of sharing it with an event
  # tap: HIToolbox carries its own Globe handler inside every process, below the
  # event stream a tap can see, so the stock emoji picker kept opening alongside
  # pounce's. Costs Fn's other jobs — no Fn+arrows, Fn+Delete, Fn+F1-F12 — which
  # is a trade this Mac can make, since Fn here is only ever the emoji key.
  haus.launcher.fnKey = "remap";

  # `exclude` REPLACES pounce's default, so Finder is restated. The rest are
  # apps on THIS Mac that keep working with no window open (VM/tunnel/mesh,
  # notifications, global hotkeys, in-flight uploads). Tailscale is accessory
  # today and listed anyway, in case upstream's packaging changes.
  haus.launcher.autoQuit = {
    enable = true;
    exclude = [
      "com.apple.finder"
      "dev.kdrag0n.MacVirt"
      "ch.protonvpn.mac"
      "io.tailscale.ipn.macsys"
      "com.google.Chrome"
      "com.cron.electron"
      "com.tinyspeck.slackmacgap"
      "app.legcord.Legcord"
      "so.cap.desktop"
      "com.loom.desktop"
    ];
  };

  # Double-clicked json/md/ts/… open in Helix, matching the hx-everywhere default.
  haus.terminal.hijackFileAssociations = true;

  # The review queue. Everything generic is the rice's; only this machine's
  # checkout paths / keys / column widths stay in programs.gh-dash below.
  haus.terminal.ghDash.enable = true;

  haus.git.org = "hausfold";

  # ---- coding agents ----
  # Codex was here and is deliberately gone: the CLI's TUI isn't worth the
  # pane. The ChatGPT GUI app stays uninstalled too.
  #
  # This does NOT cost the bar's Codex usage row. That row is polled from the
  # ChatGPT account with the OAuth token in ~/.codex/auth.json, which survives
  # the client leaving the profile — statusline-refresh.sh even refreshes the
  # token itself precisely because `codex login` needs a CLI that isn't
  # installed. `haus.bar.aiUsage.provider` is deliberately not tied to this
  # list. So leave ~/.codex/auth.json alone; deleting it is what would kill
  # the row.
  haus.ai.clients = [
    "claude"
    "opencode"
    "pi"
  ];
  # pi is the default as of 2026-08-27. Claude Code stays installed and every
  # parked Claude lane still reopens in Claude — scruff records the client per
  # lane, so this only decides what a NEW ⌘↵ pane spawns.
  #
  # What pi needs beyond the binary, haus now ships: the four packages in
  # `haus.ai.pi.packages` (sub-agents, todo, ask-a-question, web access — pi
  # ships without them on purpose), the display keys merged into
  # ~/.pi/agent/settings.json at rebuild, and scruff copying this machine's pi
  # trust decision onto each new lane so a worktree outside ~/code doesn't
  # prompt.
  haus.ai.default = "pi";

  # The endpoint every non-Claude client on this machine talks to: a loopback
  # proxy serving the Claude Max subscription, so pi and opencode cost what the
  # subscription already costs instead of billing a metered key.
  #
  # It ran for a fortnight as a hand-installed trial under
  # ~/.local/meridian-trial, whose own plist carried
  # `KeepAlive.SuccessfulExit = false` — so the first SIGTERM exited 0 and
  # launchd left the proxy down with nothing on screen but `Connection error.`
  # from every client. The room declares the agent unconditionally KeepAlive,
  # which is that bug's fix, and its activation script boots out the stray
  # co.hausfold.meridian plist on every rebuild.
  #
  # The one file that stays hand-held is `~/.pi/agent/models.json`, pointing
  # pi's `anthropic` provider at 127.0.0.1:3456. That is deliberate on haus's
  # side, not an oversight — the room's job ends at "the port answers" and it
  # writes no client's config. Dropping it puts pi back on a metered key.
  haus.ai.meridian.enable = true;

  # Name a lane after its task instead of after a word list. scruff asks the
  # adapter at ~/.config/scruff/adapters/namer/api.toml, which is
  # ~/.config/scruff/namer-api.sh: one request straight at the Messages API,
  # measured 0.7-1.1s per spawn against the built-in `claude` namer's 8-12s
  # (almost all of that the client's own start-up, not the model).
  #
  # The key is ANTHROPIC_API_KEY in the login keychain — declared in this
  # repo's secretspec.toml, valued nowhere. No key just means random lane
  # names again; it can never cost a lane.
  haus.ai.namer = "api";

  # ---- text expansion ----
  haus.snippets = {
    enable = true;
    matches = [
      {
        trigger = "@@";
        replace = "julienbmartel@gmail.com";
      }
      {
        trigger = "##";
        replace = "2044302465";
      }
    ];
  };

  # ---- theme ----
  haus.theme.accent = "pink";

  # Stylus is retired (2026-08-20). It held the same 134 nebelung styles this
  # list compiles from, and on this machine it was doing none of the three
  # things it alone can do: every style was still enabled and untouched since
  # the Jul 5 import, none carried an `updateUrl` (they came from haus's own
  # stamped bundle, so "styles that update themselves" was never true here),
  # and eighteen of them were dead weight under the compiled sheet, which wins
  # the cascade outright. haus#442 took the last real gap with it — code blocks
  # are themed now — so the choice left was coverage, and coverage is this list.
  # `haus.zen.extensions.stylus` is what to put back if that turns out wrong.
  #
  # The sites are compiled into Zen's userContent.css — no import, no state,
  # and pink follows on a rebuild (haus#416). A rebuild alone doesn't apply it:
  # Gecko reads that file once, at startup, so Zen has to be restarted.
  #
  # Size is why this is a list and not a bool: all 134 compile to ~7 MB. These
  # forty-one compile to 3.3 MB (measured), and every declaration in them is
  # applied to every document — cheap per page, but not free, so a site earns
  # its slug by being one you actually open. wikipedia (501 KB),
  # stack-overflow (438) and go.dev (310) are 39% of the sheet between them;
  # drop those three and it's 1.9 MB.
  #
  # Deliberately absent: search engines, because the default here is Kagi and
  # nebelung has no Kagi style — google/duckduckgo/brave/startpage are ~25-65 KB
  # each to theme a page that isn't the one this machine searches from. Also
  # out: google-photos (107 KB, and photos live in Photos.app), alternativeto
  # (116 KB, the biggest style in the set), chess.com/lichess, and the whole
  # education, anime and Minecraft end of the bundle.
  haus.zen.userStyles = [
    "arch-wiki"
    "bsky"
    "chatgpt"
    "claude"
    "crates.io"
    "deepl"
    "dev.to"
    "devdocs"
    "docs.rs"
    "ghostty.org"
    "github"
    "gmail"
    "go.dev"
    "google-drive"
    "google-gemini"
    "hacker-news"
    "home-manager-options-search"
    "instagram"
    "linkedin"
    "lobste.rs"
    "mdbook"
    "mdn"
    "nixos-manual"
    "nixos-search"
    "npm"
    "perplexity"
    "pypi"
    "react.dev"
    "reddit"
    "regex101"
    "spotify-web"
    "stack-overflow"
    "substack"
    "twitch"
    "twitter"
    "vercel"
    "whatsapp-web"
    "wiki.nixos.org"
    "wikipedia"
    "youtube"
    "zen-browser-docs"
  ];

  # Tab list → bar, so the media pill's ⌘ click lands on the noisy tab
  # (hausfold#311).
  haus.zen.tabBridge.enable = true;

  # ---- motion ----
  # Opt-in to the rice's snappy defaults (hausfold#286). Accepting that it
  # doesn't undo: reverting to "system" only stops the writes, not the keys.
  haus.animations = "fast";

  # ---- desktop ----
  # No desktop icons; files stay in ~/Desktop. Also makes the desktop unclickable.
  system.defaults.finder.CreateDesktop = false;

  # Screenshots go to ~/Downloads. With CreateDesktop off above they'd otherwise
  # pile up unseen in ~/Desktop.
  haus.screenshots.location = "~/Downloads";

  # ---- displays ----
  # The Studio Display, by UUID rather than `main` so docking the laptop doesn't
  # hand the built-in panel a 27" monitor's setting. Its own default (2560x1440)
  # is small at desk distance and `larger-text` overshoots to 1440x810 — this
  # panel reports nine rungs, so the halfway rule jumps four of them
  # (hausfold/haus#478 added the rung in between). Skipped with a note, not an
  # error, when the display isn't plugged in.
  haus.displays."136A50A4-8937-4C6F-B95B-9F1031C62BB3".uiScale = "slightly-larger-text";

  # ---- trackpad ----
  # No tap-to-click: palm rests fire stray clicks mid-type.
  system.defaults.trackpad.Clicking = false;

  # ---- notifications ----
  # The notification compositor, owned by the layer now that it is a room of its
  # own: haus copies the pinned, notarized bundle to a fixed /Applications/Trill.app
  # rather than a store path, so the Full Disk Access grant `trill doctor` and the
  # Silence Native Banners helper rest on survives every version bump. Nothing
  # else here changes — `trill` on PATH is core/trill.sh's wrapper either way, and
  # rules.json / github.json below stay this machine's to write.
  #
  # `compositor`, not `enable`, and the room is `notifications`, not `trill`:
  # haus draws notifications on this Mac whatever this line says (haus-notify
  # falls back to Apple's banner), so the only question here is whether haus owns
  # and pins the bundle. Named for the subject like every other room since the
  # 2026-08-16 sweep; this was `haus.trill.enable` until haus#521, which took no
  # alias, so the old spelling is simply gone.
  haus.notifications.compositor = true;

  # Which secretspec project the ROOM-declared manifest carries. This flake's
  # own secretspec.toml is project "nix", and its GITHUB_WEBHOOK_SECRET is
  # already filled in, so sharing the namespace beats a second keychain item
  # under project "haus" holding the same string.
  haus.secrets.project = "nix";

  # ---- the GitHub webhook bridge ----
  # GitHub -> hooks.hausfold.co -> the receiver here -> trill's own bridge,
  # verbatim. A raw launchd stanza until haus grew a room for it; it got reaped
  # once (e181177) precisely because it had no address.
  haus.github = {
    enable = true;
    # Empty = haus holds the HMAC secret, rather than "misconfigured": the room
    # declares the need, the secrets room renders it into
    # ~/.config/haus/secretspec.toml, and the receiver reads it through
    # `haus-secret` with its own audit reason. `haus.secrets.project` above
    # names THIS flake's secretspec project, so the value already in the login
    # keychain under GITHUB_WEBHOOK_SECRET is the one it finds — nothing to
    # re-enter, nothing duplicated. `haus-secret --list` / `--status` say so.
    secretCommand = "";
    forwardTo = [ "127.0.0.1:42787" ];
    backstop = 1800;
    hooks = [ { scope = "org:hausfold"; } ];
    tunnel = {
      enable = true;
      id = "6209f5f4-f8a2-4501-8af9-a8bb24777a89";
      hostname = "hooks.hausfold.co";
    };
  };

  # Obsidian themes per vault; this is the one to theme.
  haus.terminal.obsidianVaults = [
    "Library/Mobile Documents/iCloud~md~obsidian/Documents/notes"
  ];

  # ---- everything this machine has ----
  # One list of what this Mac has; see haus.roster's own docs in the rice.
  haus.roster = {
    # ---- the launcher ----
    # ghostty/zen defaults come from the rice; only overrides appear here.
    zen.order = 50;

    obsidian = {
      order = 20;
      key = "n";
      name = "Obsidian";
      appId = "md.obsidian";
      label = "Obsidian";
      cask = "obsidian";
    };
    things = {
      order = 30;
      key = "r";
      name = "Things3";
      appId = "com.culturedcode.ThingsMac";
      label = "Things3";
      # Paid: mas can't purchase it. The id records what to re-buy, not an install.
      appStoreId = 904280696;
    };
    slack = {
      order = 40;
      key = "s";
      name = "Slack";
      appId = "com.tinyspeck.slackmacgap";
      label = "Slack";
      cask = "slack";
    };
    claude = {
      order = 80;
      key = "c";
      name = "Claude";
      appId = "com.anthropic.claudefordesktop";
      label = "Claude";
      cask = "claude";
    };
    notion-calendar = {
      order = 90;
      key = "d";
      name = "Notion Calendar";
      appId = "com.cron.electron";
      label = "Notion Calendar";
      cask = "notion-calendar";
    };
    passwords = {
      order = 100;
      key = "p";
      name = "Passwords";
      # Launcher-only: opens/focuses in the current workspace, no pill/auto-assign.
      label = "Passwords";
    };
    # ---- apps I don't launch by keyboard ----
    # No key → installed only. Still declared, or `cleanup = "zap"` below reaps it.
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
    orbstack = {
      name = "OrbStack";
      package = pkgs.orbstack;
    };
    # Free, so mas could actually fetch this one.
    xcode = {
      name = "Xcode";
      appStoreId = 497799835;
    };

    # ---- not apps at all ----
    # Fonts and CLIs: source only, no launcher fields.
    font-hack = {
      cask = "font-hack-nerd-font";
    };
    font-jetbrains-mono = {
      cask = "font-jetbrains-mono-nerd-font";
    };
    gcloud-cli = {
      cask = "gcloud-cli";
    };
    # Also the bar's when the calendar pill is on; same id, so they merge.
    ical-buddy = {
      brew = "ical-buddy";
    };
    gogcli = {
      brew = "gogcli";
    };
    # CLI only, for `mas list` / `mas upgrade` by hand (see the App Store note below).
    mas = {
      brew = "mas";
    };
    # Claude Code is deliberately NOT here: ai.clients installs it and the
    # overlay below patches that copy. A second bin/claude would collide.

    # The GitHub webhook bridge rides a Cloudflare tunnel (hooks.hausfold.co →
    # the receiver above); haus.github.tunnel runs it. On PATH for the one-time
    # `cloudflared tunnel login` and for poking at it by hand.
    cloudflared = {
      package = pkgs.cloudflared;
    };

    # ---- system scope ----
    # systemPackages: on PATH for root, launchd jobs and non-login shells.
    biome = {
      package = pkgs.biome;
      scope = "system";
    };
    bench = {
      # The workshop CLI (~/code/workshop), as a real command rather than an
      # alias so scripts and non-interactive shells get it too.
      package = pkgs.writeShellScriptBin "bench" ''exec "$HOME/code/workshop/bench" "$@"'';
    };
  };

  # One app per workspace; each key matches the app's roster `key`, uppercased
  # for the workspace id. See haus.workspaces' own docs in the rice.
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

  # Leader then space → Spawn Agent: pick a repo, type the task, and the lane is
  # built on that repo's page while you carry on. The palette's own ⌘Space is one
  # keystroke away from the same command, but it costs a fuzzy search for a thing
  # I reach for many times a day — and the leader is already where "start
  # something" lives on this keyboard.
  #
  # `pounce run cmd:<id>`, not the script's own path: `run` goes through the
  # DAEMON, so the command resolves exactly as it does from the palette (same
  # command dirs, same shadowing) and runs in the daemon's launchd environment —
  # which is the only place HAUS_REPO_ROOTS and HAUS_LANE_NAMER exist. Exec'ing
  # the script from AeroSpace instead would silently drop both: every repo root
  # back to the fallback list, and lane names back to the stopword slug.
  #
  # `space` is free in launch mode — the built-ins are letters, punctuation and
  # arrows (modules/windows/launch-keys.nix), and haus refuses a collision at
  # eval rather than letting one silently lose.
  #
  # It replaces leader-Return → Things3 Quick Entry, which I never once used.
  haus.keys.leaderExtras = [
    {
      key = "space";
      command = "/etc/profiles/per-user/${username}/bin/pounce run cmd:spawn-agent";
      caption = "Spawn Agent";
    }
  ];

  # Fully declarative: an undeclared cask/brew is uninstalled (and zapped).
  haus.homebrew.cleanup = "zap";

  # Chase upstream latest on this machine, accepting less reproducible rebuilds.
  haus.homebrew.upgrade = true;
  haus.homebrew.autoUpdate = true;

  # Skip Gatekeeper's first-launch prompt for curated casks — a cask with a
  # nested quarantined helper otherwise re-prompts on EVERY launch. Must be the env var,
  # not `homebrew.caskArgs.no_quarantine`: Homebrew 6 dropped the install flag,
  # so caskArgs makes every new cask install fail the rebuild's `brew bundle`.
  homebrew.onActivation.extraEnv.HOMEBREW_CASK_OPTS = "--no-quarantine";

  # Which pills exist; `haus.bar.bottom.items` below places them, and anything
  # this list switches on but that list never names stays on the menu bar.
  # Off on purpose: wifi/volume (menu bar + HUD already say it) and harvest.
  haus.bar.items = {
    agents = true;
    aiUsage = true;
    elgato = true;
    caffeinate = true;
    cpu = true;
    memory = true;
    calendar = true;
    weather = true;
    github = true;
    # trill's inbox, one click from a bar that is always on screen: the app's
    # own menu-bar item is unreachable here, since `haus.bar.enable` hides
    # macOS's menu bar outright. Draws nothing at all without Trill.app, so it
    # is safe to state unconditionally — and `haus.notifications.compositor`
    # above means this Mac always has it.
    trill = true;
    wifi = false;
  };

  haus.bar.battery.hideOver = 80;
  haus.bar.clock.mode = "compact";

  # This machine tracks the rice, so the "haus update" nag is wanted.
  haus.bar.logo.updateCheck = true;

  # Both bars. `top` is load-bearing: `auto` would drop the menu bar down beside
  # the second bar whenever this Mac is docked.
  haus.bar.position = "top";
  haus.bar.bottom = {
    enable = true;
    items = {
      # No `page` here any more — the page readout is not a movable pill. It
      # answers WHERE this window is, which is a property of the workspace, so
      # it lives beside the front app in the menu bar's left group and haus
      # draws it wherever a workspace carries pages. This left group is now
      # "what is my work doing", start to finish.
      # Agent readouts under the panes they describe; media alone in the center.
      agents = "left";
      aiUsage = "left";
      # Beside them on purpose. The left group is already "what is my work
      # doing" — which panes are busy, what they have spent — and the GitHub
      # pill answers the same question one step further out: which of it has
      # landed, and what is stuck. The menu bar's right corner is the machine's
      # own readouts, and this is not one of those.
      github = "left";
      media = "center";
      # The right group down here is the machine's own vitals and switches —
      # what it is spending and what is toggled. `weather` and `focus` are
      # neither: the forecast is the world outside the Mac, and the moon is the
      # one thing I reach for mid-sentence to shut everything up. Both now sit
      # in the menu bar's right corner beside the clock and the trill bell,
      # which is the always-visible strip — naming a pill here MOVES it, so
      # leaving them out is what puts them up top.
      cpu = "right";
      memory = "right";
      elgato = "right";
      caffeinate = "right";
    };
  };

  # Written once per installed client, so keep this CLIENT-NEUTRAL and universal;
  # repo-specific rules belong in each project's own AGENTS.md.
  haus.ai.instructions = ''
    # Global instructions

    How I (julienmartel) like to work, across every repo and every client.
    Repo-specific detail lives in each project's own AGENTS.md, not here.

    ## How to answer me

    Load the `brief` skill at the start of every session and hold its shape all
    session: verdict first, at most 5 anchored steps, and escalate to me only at
    3/5 or above, with a recommendation and a reversal cost. It governs code
    work, research and anything I paste. "drop brief" / "full mode" turns it off.
    The body is `~/.config/nix/claude/skills/brief/SKILL.md`, linked
    OUT-of-store into both `~/.claude/skills/brief` and `~/.agents/skills/brief`
    (Codex and OpenCode read the second), so editing it is live in the next
    pane with no rebuild. Same for `ship`, `park` and `things` (my Things 3
    to-dos — read its SKILL.md before touching my list). If your client does not
    load skills, read the SKILL.md by path; it is plain markdown.

    `/handoff` ships with scruff, not this repo (`ai/handoff/SKILL.md` in
    hausfold/scruff). It writes a brief a cold session can act on: `/handoff`
    copies it to the clipboard, `/handoff spawn [repo]` opens it as a real lane
    with its own checkout, branch and window. Edit it there.

    ## Working in a git worktree

    Detect it: `git rev-parse --git-common-dir` points outside your toplevel.
    When it does:

    - **Commit, push and open the PR without asking.** Standing permission, all
      three. The only step that waits for me is *merging*. A verified change
      left uncommitted, unpushed or without a PR is an unfinished task.
    - **Build and verify without asking.** A build is read-only toward every
      checkout, a child repo's included, so it is exactly what a worktree is for
      — do not stop at "the diff is ready". Only *activation* (`darwin-rebuild
      switch` and its wrappers) is mine: it is machine-wide and serial, so five
      parallel agents each with a good reason to switch would silently overwrite
      one another. Build, then hand me the exact command. Where a repo's tooling
      enforces this it names its own override in the refusal — use that if I
      have already asked you to activate, rather than asking again.
    - **Running a repo's push/ship step is fine** — it only pushes commits that
      already exist and never activates.
    - **Land through a PR — never a direct push or a local `git merge` into
      `main`,** and never touch the main checkout's files. Parallel agents
      pushing straight to main have clobbered each other; a PR is
      conflict-detected and atomic. Merging is my call, which means do not merge
      *unprompted*, not "never merge": when I say `/ship`, "ship it" or "merge
      and clean up", that IS the go-ahead — `gh pr merge`, still never a local
      merge. Absent that, stop at "PR open" and give me the link.
    - **Do not sync with main unless a real conflict forces it, and then
      rebase.** GitHub merges a PR that is merely behind. `git rebase
      origin/main`, then force-push: my `worktree-*` branches are single-agent
      and nobody bases on them, so rewriting them is free. Never `git merge
      origin/main` into a branch — it puts commits I did not write in my PR's
      commit list. `flake.lock` is never hand-merged: take main's wholesale
      (`git checkout --theirs flake.lock`), then re-run `nix flake update
      <input>` if the branch genuinely needed a newer pin.
    - **`/ship` finishes the whole job**: merge the PR, then clean up every
      worktree this session spun up — a sibling-repo worktree is not
      auto-reaped, so merge its PR too and `git worktree remove` it. Then report
      and stop. It does not close this pane or open one. The current worktree is
      not reaped (you are still in it); it goes when I close the pane.

    A plain non-worktree session on `main` is fine for a small one-off, and
    committing to main directly is expected there. The PR rule exists to stop
    *parallel* agents clobbering each other.

    ## How I ship

    **Ship by default, sized to the change — in repos I own solo** (my personal
    infra: the hausfold family, qnap-mediastack, `~/.config/nix`). In shared or
    client repos, prepare the change and ask before pushing.

    - **Small** (bugfix, typo, config/theme tweak, version bump, docs): commit,
      verify and ship in the same turn without asking. A verified fix left
      unshipped is a bug, not a finished task.
    - **Big or risky** (new feature, refactor, anything hard to roll back,
      anything a user could feel break): verify it works, then ask. Once
      approved, drive it all the way to shipped.
    - **Releases and user-facing publishes are always gated.** Propose one after
      shipping user-facing changes; never tag or publish unprompted.
    - Unsure which bucket? Ask.

    ## Repos nested inside other repos

    The hausfold family (`nebelung`, `pounce`, `haus`, …) sits under
    `~/code/workshop`, whose `.gitignore` lists each child. **That nesting only
    keeps the outer tree clean; each child is a full, independent repo I own
    solo.** `cd` into it and commit / push / ship it under its own rules and the
    policy above — a child being gitignored by the parent says nothing about
    committing inside it, and is not a signal that git ops there are risky. When
    I ask for a cross-repo flow, run it end to end, landing each branch by
    merging its PR, without re-confirming each repo word for word.

    ## Do not drive my terminal

    Do not open or close Ghostty windows for me. If a task genuinely needs one,
    ask first or hand me the command. To do a main-checkout-only thing from a
    worktree (activating after a ship), `cd` to the main checkout and run it in
    place rather than spawning a window to carry it.

    ## How I verify

    **Verify by actually running it**, not by eyeballing the diff. Testing in
    prod is acceptable house style for my personal infra: build it, run it,
    observe the real behavior. Prefer a project's own run/verify skill.

    ## Memory

    Auto-memory is off, deliberately: `autoMemoryEnabled = false` in
    `~/.claude/settings.json`, set on every rebuild by `hosts/mbp/default.nix`.
    **The code, the git history and each repo's own AGENTS.md are the source of
    truth for code work.** Do not ask for it back on, and do not keep a parallel
    note store anywhere else. Something worth carrying between sessions goes in
    the repo it belongs to: a line in AGENTS.md, a comment beside the code that
    embodies it, or a commit message. If it fits none of those, it was probably
    not worth keeping.

    Account-level memory in the Claude apps (iOS, web chat) is a separate
    setting and stays on. That is for non-code conversations, not this.

    ## Keeping docs honest

    If something in an AGENTS.md, CLAUDE.md, README or docs file is wrong or
    stale, fix it in the same change rather than working around it. Keep those
    files short and *current* — state what is true now, not how it got that way.
    Push detail into the matching docs file rather than growing the top-level
    one.
  '';

  # ---- Claude Code, patched, as an OVERLAY rather than a package ----
  # An overlay, not a home.packages entry: the rice already installs
  # `pkgs.claude-code` from ai.clients, and two builds shipping `bin/claude`
  # would collide. Three things Claude Code has no setting for:
  #  1. declutter-claude-footer.py — drop the permission-mode footer row and the
  #     right-hand chip strip. Fails the build if an update reshapes them; the
  #     script header says how to re-derive the regexes.
  #  2. statusline-permission-mode.py — emit `permission_mode` in the statusline
  #     payload, so the rice's chip tracks shift+tab live instead of lagging
  #     behind the transcript.
  #  3. caffeinate shadowed with a no-op on claude's PATH only, so the agent
  #     can't block sleep. Everything else still gets /usr/bin/caffeinate.
  nixpkgs.overlays = [
    (final: prev: {
      claude-code =
        let
          # `prev`, never `final` — overriding a package in terms of itself is
          # infinite recursion, not a patch.
          patchedCC = prev.claude-code.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              prev.python3
              prev.darwin.autoSignDarwinBinariesHook # re-sign the patched Mach-O in fixup
            ];
            postInstall = (old.postInstall or "") + ''
              python3 ${./declutter-claude-footer.py} "$out/bin/.claude-wrapped"
              python3 ${./statusline-permission-mode.py} "$out/bin/.claude-wrapped"
            '';
          });
        in
        prev.symlinkJoin {
          name = "claude-code-no-caffeinate";
          paths = [ patchedCC ];
          nativeBuildInputs = [ prev.makeBinaryWrapper ];
          postBuild = ''
            rm "$out/bin/claude"
            makeBinaryWrapper "${patchedCC}/bin/claude" "$out/bin/claude" \
              --inherit-argv0 \
              --prefix PATH : "${prev.writeShellScriptBin "caffeinate" "exit 0"}/bin"
          '';
          # symlinkJoin invents its own (empty) meta, which would drop the
          # platform list the rice's ai.clients assertion reads and the
          # license the unfree check reads. Carry the real one through.
          inherit (prev.claude-code) meta;
        };
    })
  ];

  # App Store stays manual here (haus.appStore.install off): mas can't buy a
  # paid app (Things), and I don't want a rebuild touching my Apple ID.
  # System Settings → App Store → automatic updates keeps them current.

  # ---- personal home layer: extra packages, private git config, secrets ----
  home-manager.users.${username} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # ---- pounce: opt-in command plugins ----
      # pounce's optional command plugins ship OFF; this list is the switch.
      # Their CLI deps already come from the rice.
      pouncePlugins = [
        "audio"
        "bluetooth"
        "caffeinate"
        "docker"
        "github"
        "perplexity"
        "spotify"
        "ssh"
        "tailscale"
      ];

      # Symlinked script-by-script below rather than added to home.packages,
      # which would collide with the rice's own pounce-commands.
      pouncePluginPkg = pkgs.pounce-commands.override { plugins = pouncePlugins; };

    in
    {
      # Dev loop for hacking on pounce: rebuild against the LOCAL checkout
      # (uncommitted edits) instead of the pinned input. See AGENTS.md.
      # `things today`, `things add …` at a prompt. An alias rather than a
      # PATH entry: the script is only ever a thin wrapper and lives in this
      # repo, so it should follow the checkout, not get copied to the store.
      programs.zsh.shellAliases.things = "$HOME/.config/nix/claude/skills/things/things";

      programs.zsh.shellAliases.rebuild-pounce = ''
        (cd "$HOME/.config/nix" \
          && nix build .#darwinConfigurations.mbp.system \
               --override-input haus/pounce "path:$HOME/code/workshop/pounce" \
          && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp)
      '';

      # Into ~/.config/pounce/commands, pounce's highest-precedence runtime dir.
      # xdg.configFile, not home.file: a dynamic attrset can't merge with the
      # static `home.file."…".source` attr-paths below. Store paths so these
      # can't go dangling the way the old hand-made symlinks silently did.
      xdg.configFile = lib.listToAttrs (
        map (
          p:
          lib.nameValuePair "pounce/commands/${p}.sh" {
            source = "${pouncePluginPkg}/share/pounce/commands/${p}.sh";
          }
        ) pouncePlugins
      );

      # …and reap the old hand-made symlinks: home-manager refuses to link over
      # an unmanaged path, so a dangling one fails the rebuild. Before
      # checkLinkTargets, and only ever removes BROKEN links.
      home.activation.pounceCommandsReapDangling = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        run sh -c '
          dir="$0"
          [ -d "$dir" ] || exit 0
          for link in "$dir"/*; do
            [ -L "$link" ] && [ ! -e "$link" ] || continue
            echo "→ pounce: removing dangling command symlink $link"
            rm -f "$link"
          done
        ' "$HOME/.config/pounce/commands"
      '';

      programs.git.settings = {
        http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
        core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      };

      # ---- gh-dash: my half of it (see haus.terminal.ghDash above) ----
      # Only what can't be shipped to anyone else: my checkout paths, my keys,
      # a laptop's column widths. The rice's lists are mkDefault, so overriding
      # one means restating it whole (gh-dash reads a section list as a unit).
      programs.gh-dash = {
        settings = {
          defaults = {
            view = "prs";
            prsLimit = 20;
            issuesLimit = 10;
            notificationsLimit = 20;
            refetchIntervalMinutes = 5;
            prApproveComment = "LGTM";

            # Off by default: on a laptop the preview eats half the width. `p`
            # toggles it when the CI detail is what you're after.
            preview = {
              open = false;
              width = 0.45;
              height = 0.6;
              position = "auto";
            };

            # Hide what's constant in a solo org (author, base) or that I never
            # act on (labels/assignees/createdAt), and let `title` take the slack.
            layout.prs = {
              updatedAt.width = 6;
              createdAt.hidden = true;
              repo.width = 14;
              author.hidden = true;
              authorIcon.hidden = true;
              assignees.hidden = true;
              labels.hidden = true;
              base.hidden = true;
              lines.width = 10;
              numComments.width = 4;
            };
            layout.issues = {
              createdAt.hidden = true;
              repo.width = 14;
              creator.hidden = true;
              creatorIcon.hidden = true;
              assignees.hidden = true;
            };
          };

          # Commands BLOCK the TUI until they exit, so only things I want to
          # take over the pane (scruff, lazygit) — never `bench try`.
          # Custom keys silently SHADOW built-ins with no warning, so check
          # keys.go / prKeys.go before adding one. Free today: b f i n and most
          # capitals (B D E F I J K M N O S T U Z).
          keybindings.prs = [
            {
              # Jump into the agent session behind this PR (scruff names the
              # worktree after the branch minus the `worktree-` prefix).
              key = "H";
              name = "scruff session";
              command = ''scruff "$(printf '%s' {{.HeadRefName}} | sed 's/^worktree-//')"'';
            }
            {
              key = "z";
              name = "lazygit";
              command = "cd {{.RepoPath}} && lazygit";
            }
          ];

          # Where my checkouts sit on disk — the half the rice can't know.
          # Exact keys beat the wildcard. ghOrg, not a literal, so these globs
          # and the rice's section filters can't name different owners.
          repoPaths = {
            "${ghOrg}/*" = "${config.home.homeDirectory}/code/workshop/*";
            "${ghOrg}/workshop" = "${config.home.homeDirectory}/code/workshop";
            "${ghOrg}/.github" = "${config.home.homeDirectory}/code/workshop/org-profile";
            "JulienMartel/nix-config" = "${config.home.homeDirectory}/.config/nix";
          };

          # delta is already themed by the rice.
          pager.diff = "delta";

          theme.ui = {
            sectionsShowCount = true;
            table = {
              compact = true;
              showSeparator = false;
            };
          };

          confirmQuit = false;
          showAuthorIcons = false;
          # Don't open on a filter prompt; open on the dashboard.
          smartFilteringAtLaunch = false;
        };
      };

      # My five personal skills. The instructions above are what make `brief`
      # load every session; these just put the bodies on disk. mkOutOfStoreSymlink
      # so editing a SKILL.md is live in the next pane with no rebuild, and the
      # targets are in THIS repo, which always lives at ~/.config/nix.
      # brief — answer shape: verdict first, ≤5 steps, escalate only at ≥3/5.
      home.file.".claude/skills/brief".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/brief";

      # ship — repo-agnostic fallback (PR → merge → clean up → report); a repo's
      # own scoped ship skill wins over this one.
      home.file.".claude/skills/ship".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/ship";

      # park — set the tree aside as a `wip:` commit, never `git stash`: the
      # stash stack is shared across every worktree of a repo, so parallel
      # agents pop each other's entries. Covers `/unpark` too.
      home.file.".claude/skills/park".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/park";

      # handoff moved OUT of here and into scruff — it is `scruff spawn --prompt`'s
      # missing half (how to write the brief a cold lane opens on), so it lives
      # with the flag and ships to everyone who installs scruff. haus's
      # `ai.skill` links it, and this file must NOT also define
      # ~/.claude/skills/handoff — two definitions of one home.file path is an
      # eval conflict, not a last-wins. Edit it at hausfold/scruff's
      # ai/handoff/SKILL.md; it is a store path here, so no longer live-editable.

      # things — my Things 3 to-do list. Reads go at the app's SQLite file
      # -readonly (no Automation prompt, nothing stolen from the screen);
      # writes go through the documented `things:///` URL scheme, dispatched
      # with `open -g` so Things never comes to the front. The dir carries a
      # `things` helper script beside SKILL.md, which is why it's a whole-dir
      # out-of-store symlink like the rest — edit either, live next pane.
      home.file.".claude/skills/things".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/things";

      # The same four, linked again under ~/.agents/skills — the dir BOTH Codex
      # and OpenCode scan (verified with `codex debug prompt-input` /
      # `opencode debug skill`). Otherwise "load the `brief` skill" is an order
      # only Claude Code can obey. Both dirs is safe: clients dedupe by
      # frontmatter `name`, and Claude Code never reads ~/.agents.
      home.file.".agents/skills/brief".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/brief";
      home.file.".agents/skills/ship".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/ship";
      home.file.".agents/skills/park".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/park";
      home.file.".agents/skills/things".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/things";

      # ---- trill's copy of the webhook HMAC secret ----
      # trill verifies GitHub's signature itself
      # (Providers/GitHub/GitHubWebhookMapper.swift) and should: haus forwards
      # each delivery byte for byte, signature header included, precisely so
      # nothing downstream has to trust the receiver. But that left ONE secret
      # in TWO hand-maintained places, and the divergence is silent in the worst
      # way — rotate the hook, update the keychain, and haus keeps verifying
      # while trill drops every delivery as a forgery, saying nothing.
      #
      # So `secret` in github.json is derived, not authored: the login keychain
      # is the source and this writes trill's copy. `login` and `port` are
      # trill's own config and are read straight back out untouched. After a
      # rotation trill needs a rebuild where haus only needs a `launchctl
      # kickstart` — it reads its secret at agent start, this file at
      # activation.
      #
      # Via $SECRET in the environment, never argv: `ps` shows arguments to
      # every user on the box. Both tools pinned from the store — activation
      # runs with a bare PATH. A keychain that won't answer, or a Mac with no
      # trill, leaves the file alone rather than blanking the secret.
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

      # ---- trill's rules file ----
      # Merged, not owned. `rules.json` also carries `quietHours` and
      # `resolvers` — a resolver is the only place a command may live, so
      # clobbering the file from here would silently disarm every `--until`
      # poller. The patch keeps every key and every rule this machine didn't
      # declare, drops only an older copy of a rule nix names, and appends
      # nix's at the end so a hand-written rule keeps its priority.
      #
      # A missing file is created rather than skipped: an empty rules file is
      # valid, trill watches it live, and there is nothing here to lose.
      home.activation.trillRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run env MINE=${lib.escapeShellArg (builtins.toJSON trillRules)} \
          ${pkgs.python3}/bin/python3 ${./json-patch.py} rules \
          "$HOME/.config/trill/rules.json" MINE
      '';

      # ---- Claude Code's settings.json ----
      # Merged, not owned: Claude rewrites this file itself, so everything it or
      # `/config` put there has to survive. What nix declares here:
      #  • WorktreeCreate/Remove → `scruff hook create|remove` (note the `hook`
      #    subcommand), so ⌘A's worktrees land under ~/.cache/claude-worktrees,
      #    get parked on pane close, and stay resumable.
      #  • UserPromptSubmit/Notification/Stop/SessionEnd → agents-hook.sh, which
      #    feeds the `agents` bar paw. Host-side because it names a plugin path.
      #  • verbose = false: new sessions start with tool output collapsed (⌃O
      #    still expands).
      #  • autoMemoryEnabled = false: auto-memory is off machine-wide — no reads
      #    from or writes to ~/.claude/projects/*/memory. The repo is the source
      #    of truth for code work (see the Memory stanza in ai.instructions).
      #    Account-level memory in the Claude apps is a separate, untouched
      #    setting.
      # Toggling any of these via `/config` lasts only until the next rebuild.
      #
      # The allowlist is UNIONed rather than set, so a grant Claude earned at a
      # prompt is never dropped. It pre-approves what auto mode still escalates
      # (git/gh/worktree/push) — the agent-worktree flow's bread and butter.
      # Personal, not rice: leash length is a per-user call and `git:*`/`gh:*`
      # are broad, and auto mode's background safety checks still apply.
      home.activation.claudeCodePersonal =
        let
          settings = "${config.home.homeDirectory}/.claude/settings.json";
          agentsHook = "${config.home.homeDirectory}/.config/sketchybar/plugins/agents-hook.sh";
          cmd = command: [
            {
              hooks = [
                {
                  type = "command";
                  inherit command;
                }
              ];
            }
          ];
          patch = {
            hooks = {
              WorktreeCreate = cmd "/run/current-system/sw/bin/scruff hook create";
              WorktreeRemove = cmd "/run/current-system/sw/bin/scruff hook remove";
              UserPromptSubmit = cmd "${agentsHook} working";
              Notification = cmd "${agentsHook} waiting";
              Stop = cmd "${agentsHook} idle";
              SessionEnd = cmd "${agentsHook} remove";
            };
            verbose = false;
            autoMemoryEnabled = false;
          };
          allow = [
            "Bash(git:*)"
            "Bash(git worktree:*)"
            "Bash(gh:*)"
            "Bash(bench:*)"
            "Bash(wt:*)"
            "Bash(scruff:*)"
            "Bash(haus:*)"
          ];
          # `union` adds and never removes, so a name this list used to carry
          # outlives the rebuild that stopped declaring it. `drop` is the other
          # half, and it runs after the union. `Bash(holt:*)` is scruff's old
          # spelling (renamed 2026-08-27) and the binary is gone at scruff
          # 1.1.0 — delete this list, and the `drop` call below, once a rebuild
          # has run with it.
          retire = [ "Bash(holt:*)" ];
          patchWith = args: ''
            run ${pkgs.python3}/bin/python3 ${./json-patch.py} ${args}
          '';
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          patchWith "merge ${settings} ${lib.escapeShellArg (builtins.toJSON patch)}"
          + patchWith "union ${settings} permissions.allow ${lib.escapeShellArg (builtins.toJSON allow)}"
          + patchWith "drop ${settings} permissions.allow ${lib.escapeShellArg (builtins.toJSON retire)}"
        );

      # Private tooling that shouldn't live in the public rice.
      programs.zsh.initContent = lib.mkAfter ''
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
}
