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
  ];
  haus.ai.default = "claude";

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

  # ---- trill: GitHub bridge tunnel ----
  # GitHub webhooks → hooks.hausfold.co → this agent → trill's localhost
  # receiver (trill PR #11; HMAC auth lives in trill, this is only transport).
  # Raw nix-darwin because no haus.* option covers tunnels. Gated on the
  # tunnel's config file so a machine that hasn't run the one-time bootstrap
  # (`cloudflared tunnel login` + `tunnel create trill-hooks` + `tunnel route
  # dns`) gets a dormant agent, not a crash loop. Credentials stay in
  # ~/.cloudflared, written by cloudflared itself — nothing secret in here.
  launchd.user.agents.trill-github-tunnel.serviceConfig = {
    ProgramArguments = [
      "${pkgs.cloudflared}/bin/cloudflared"
      "--config"
      "/Users/${username}/.cloudflared/trill-hooks.yml"
      "tunnel"
      "run"
      "trill-hooks"
    ];
    RunAtLoad = true;
    KeepAlive.PathState."/Users/${username}/.cloudflared/trill-hooks.yml" = true;
    StandardOutPath = "/Users/${username}/Library/Logs/trill-github-tunnel.log";
    StandardErrorPath = "/Users/${username}/Library/Logs/trill-github-tunnel.log";
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

    # trill's GitHub bridge rides a Cloudflare tunnel (hooks.hausfold.co →
    # localhost:42787); the launchd agent below runs it. On PATH for the
    # one-time `cloudflared tunnel login` and for poking at it by hand.
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

  # Leader then Return → Things3's Quick Entry panel.
  haus.keys.leaderExtras = [
    {
      key = "enter";
      command = "osascript -e 'tell application \"Things3\" to show quick entry panel'";
      caption = "Things Quick Entry";
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

  # Which pills exist; `haus.bar.bottom.items` below places them.
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
      weather = "right";
      cpu = "right";
      memory = "right";
      focus = "right";
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
    (Codex, OpenCode and pi read the second), so editing it is live in the next
    pane with no rebuild. Same for `ship`, `park` and `things` (my Things 3
    to-dos — read its SKILL.md before touching my list). If your client does not
    load skills, read the SKILL.md by path; it is plain markdown.

    `/handoff` is NOT one of those any more — it ships with holt now
    (`ai/handoff/SKILL.md` in hausfold/holt), because it is the missing half of
    `holt spawn --prompt`: how to write a brief a cold session can act on. Same
    two jobs, one extra ending — `/handoff` copies it to the clipboard as
    before, and `/handoff spawn [repo]` opens it as a real lane with its own
    checkout, branch and window. Editing it means editing that repo, not this
    one.

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
      osConfig,
      nebelung,
      inputs,
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

      # ---- pi: the Nebelung port ----
      # haus's own resolver, not a re-derivation of it: it turns
      # haus.theme.{flavor,contrast} into the palette-variant names, and it is
      # the file that would move if a new axis is added. `inputs.self` is the
      # haus flake (extraSpecialArgs passes haus's whole `inputs` through), so
      # this reads the same module modules/{terminal,bar,theme} read.
      nb = import "${inputs.self}/modules/lib/nebelung.nix" {
        inherit lib nebelung;
        theme = osConfig.haus.theme;
      };

      # Both poles, always — `theme` in pi's settings takes a "light/dark" pair
      # and follows the terminal's detected background, so a light Ghostty gets
      # latte without a rebuild. darkVariant/lightVariant still track
      # haus.theme.contrast, so a high-contrast desktop renders the
      # high-contrast palettes here too.
      piThemes =
        map
          (variant: {
            name = variant;
            json = (pkgs.formats.json { }).generate "pi-theme-${variant}.json" (
              import ../../pi/theme.nix {
                inherit lib;
                name = variant;
                palette = nebelung.palettes.${variant};
                accent = osConfig.haus.theme.accent;
              }
            );
          })
          [
            nb.darkVariant
            nb.lightVariant
          ];

    in
    {
      # ---- pi ----
      # Not `haus.ai.clients`: that option's enum is claude/codex/opencode, so
      # the layer ships pi no keybind, no Spawn Agent pane and no generated
      # instructions file. It is `pi` on PATH plus the four files below — a
      # trial, dressed as a first-class client, entirely from this host.
      #
      # nixpkgs builds it from the earendil-works/pi source (plus the official
      # npm tarball, for a model catalog upstream gitignores) and has a
      # nix-update updateScript, so it tracks npm closely — nixpkgs and npm
      # were both on 0.84.2 the day this landed, and our pin gave 0.84.1. So
      # version lag here is `haus update` cadence, not the package's. Pi's own
      # self-update can't work against the read-only store, so bump the input
      # instead — and nixpkgs already knows that: its wrapper exports
      # PI_SKIP_VERSION_CHECK=1 and PI_TELEMETRY=0 as `${VAR-default}`, i.e.
      # defaults this machine could override but has no reason to. Nothing here
      # needs to set either.
      home.packages = [ pkgs.pi-coding-agent ];

      # Nebelung, both poles, as store files. Store and not an out-of-store
      # symlink deliberately: pi hot-reloads the active theme file on edit, but
      # these are RENDERED from haus.theme.{accent,flavor,contrast}, so the way
      # to change a colour is to change the accent and rebuild — the same loop
      # ghostty, helix and the bar are on. Hand-editing the JSON would be a
      # change the next rebuild silently reverts.
      # One directory, one static attr-path: `home.file = <expr>` would collide
      # with the `home.file."…".source` lines further down, the same clash the
      # pounce block below solves by reaching for xdg.configFile. pi globs
      # ~/.pi/agent/themes/*.json, so a linked tree is exactly as good.
      home.file.".pi/agent/themes".source = pkgs.linkFarm "pi-themes-nebelung" (
        map (t: {
          name = "${t.name}.json";
          path = t.json;
        }) piThemes
      );

      # pi reads ~/.pi/agent/AGENTS.md at startup, so my global instructions
      # reach it the same way haus writes them into ~/.claude/CLAUDE.md for the
      # clients it does know. Same single source (`haus.ai.instructions`,
      # deliberately client-neutral), plus the pi-shaped preamble haus would
      # have generated — pi's own paths, not Claude's, so a pi session told to
      # fix its instructions edits the right file.
      home.file.".pi/agent/AGENTS.md".text = ''
        <!-- Generated by Nix from `haus.ai.instructions` in
             ~/.config/nix/hosts/mbp/default.nix. Edit it there, then
             `haus rebuild` — an edit here is reverted by the next rebuild.

             pi is NOT a haus client (haus.ai.clients has no `pi`), so this
             file and everything else under ~/.pi/agent is wired by hand in
             that same host file's `---- pi ----` block, not by the layer.
             Skills come from ~/.agents/skills, which pi reads natively. -->

      ''
      + osConfig.haus.ai.instructions;

      # Settings are SEEDED, not owned: pi rewrites settings.json itself
      # (`/settings`, and picking a theme saves it), so a read-only store
      # symlink would break the app. Same jq-merge shape as the Claude Code
      # blocks below — everything not named here is pi's to keep, and anything
      # named here goes back to this value on the next rebuild.
      #
      #   theme          "<light>/<dark>" is pi's pair syntax: it follows the
      #                  terminal's detected background, so one setting covers
      #                  both Ghostty polarities.
      #   skills         ~/.agents/skills (brief, ship, park, things) is a
      #                  built-in pi location — nothing to declare. These three
      #                  are the haus-installed skills that live only under
      #                  ~/.claude/skills; naming the directories one by one
      #                  rather than the parent is what keeps the four shared
      #                  ones from being discovered twice.
      #   telemetry      off. Belt to the wrapper's braces — PI_TELEMETRY=0
      #                  already covers it for `pi` on PATH, but the setting is
      #                  the declarative half and survives a pi invoked some
      #                  other way (`node …/dist/index.js`, an SDK embed).
      #
      # Deliberately NOT seeded: `defaultProvider`/`defaultModel` (pi has never
      # been logged in here — ~/.pi/agent/auth.json is still `{}` — and pinning
      # a model before `/login` picks a provider just fights the first run), and
      # `externalEditor` (unset falls through to $VISUAL/$EDITOR, which the
      # layer already points at haus.terminal.editor).
      home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run sh -c '
          settings="$0"
          mkdir -p "''${settings%/*}"
          tmp="$settings.hm-seed"
          if [ -s "$settings" ]; then base="$settings"; else base="$tmp.base"; printf "{}" > "$base"; fi
          ${pkgs.jq}/bin/jq \
            --arg theme "$1" \
            ".theme = \$theme
             | .enableInstallTelemetry = false
             | .skills = [
                 \"~/.claude/skills/haus\",
                 \"~/.claude/skills/holt\",
                 \"~/.claude/skills/handoff\"
               ]" \
            "$base" > "$tmp"
          mv "$tmp" "$settings"
          rm -f "$tmp.base"
        ' "$HOME/.pi/agent/settings.json" "${nb.lightVariant}/${nb.darkVariant}"
      '';

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
          # take over the pane (holt, lazygit) — never `bench try`.
          # Custom keys silently SHADOW built-ins with no warning, so check
          # keys.go / prKeys.go before adding one. Free today: b f i n and most
          # capitals (B D E F I J K M N O S T U Z).
          keybindings.prs = [
            {
              # Jump into the agent session behind this PR (holt names the
              # worktree after the branch minus the `worktree-` prefix).
              key = "H";
              name = "holt session";
              command = ''holt "$(printf '%s' {{.HeadRefName}} | sed 's/^worktree-//')"'';
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

      # handoff moved OUT of here and into holt — it is `holt spawn --prompt`'s
      # missing half (how to write the brief a cold lane opens on), so it lives
      # with the flag and ships to everyone who installs holt. haus's
      # `ai.skill` links it, and this file must NOT also define
      # ~/.claude/skills/handoff — two definitions of one home.file path is an
      # eval conflict, not a last-wins. Edit it at hausfold/holt's
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

      # Claude Code — reinstate our hooks in settings.json on every rebuild.
      #  • WorktreeCreate/Remove → `holt hook create|remove` (note the `hook`
      #    subcommand), so ⌘A's worktrees land under ~/.cache/claude-worktrees,
      #    get parked on pane close, and stay resumable.
      #  • UserPromptSubmit/Notification/Stop/SessionEnd → agents-hook.sh, which
      #    feeds the `agents` bar paw. Host-side because it names a plugin path.
      # Claude owns settings.json, so we jq-merge only our keys and never own the
      # file. jq is pinned from the store: activation runs with a bare PATH.
      home.activation.claudeCodeHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run sh -c '
          settings="$0"
          holtbin="$1"
          hook="$2"
          mkdir -p "''${settings%/*}"
          tmp="$settings.hm-seed"
          if [ -s "$settings" ]; then base="$settings"; else base="$tmp.base"; printf "{}" > "$base"; fi
          ${pkgs.jq}/bin/jq \
            ".hooks.WorktreeCreate = [{hooks:[{type:\"command\",command:\"''${holtbin} hook create\"}]}]
             | .hooks.WorktreeRemove = [{hooks:[{type:\"command\",command:\"''${holtbin} hook remove\"}]}]
             | .hooks.UserPromptSubmit = [{hooks:[{type:\"command\",command:\"''${hook} working\"}]}]
             | .hooks.Notification = [{hooks:[{type:\"command\",command:\"''${hook} waiting\"}]}]
             | .hooks.Stop = [{hooks:[{type:\"command\",command:\"''${hook} idle\"}]}]
             | .hooks.SessionEnd = [{hooks:[{type:\"command\",command:\"''${hook} remove\"}]}]" \
            "$base" > "$tmp"
          mv "$tmp" "$settings"
          rm -f "$tmp.base"
        ' "$HOME/.claude/settings.json" "/run/current-system/sw/bin/holt" "$HOME/.config/sketchybar/plugins/agents-hook.sh"
      '';

      # Pre-approve what auto mode still escalates (git/gh/worktree/push) — the
      # agent-worktree flow's bread and butter. Personal, not rice: leash length
      # is a per-user call and `git:*`/`gh:*` are broad. UNIONed into Claude's
      # own grants; auto mode's background safety checks still apply.
      home.activation.claudeCodePermissionAllow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run sh -c '
          settings="$0"
          mkdir -p "''${settings%/*}"
          tmp="$settings.hm-seed"
          if [ -s "$settings" ]; then base="$settings"; else base="$tmp.base"; printf "{}" > "$base"; fi
          ${pkgs.jq}/bin/jq \
            ".permissions.allow = ((.permissions.allow // []) + [
                \"Bash(git:*)\",
                \"Bash(git worktree:*)\",
                \"Bash(gh:*)\",
                \"Bash(bench:*)\",
                \"Bash(wt:*)\",
                \"Bash(holt:*)\",
                \"Bash(haus:*)\"
             ] | unique)" \
            "$base" > "$tmp"
          mv "$tmp" "$settings"
          rm -f "$tmp.base"
        ' "$HOME/.claude/settings.json"
      '';

      # Personal UI prefs on top of the rice's house-style defaults.
      # verbose = false: new sessions start with tool output collapsed (⌃O still
      # expands). Toggling it via `/config` lasts only until the next rebuild.
      home.activation.claudeCodePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run sh -c '
          settings="$0"
          mkdir -p "''${settings%/*}"
          tmp="$settings.hm-seed"
          if [ -s "$settings" ]; then base="$settings"; else base="$tmp.base"; printf "{}" > "$base"; fi
          ${pkgs.jq}/bin/jq ".verbose = false" "$base" > "$tmp"
          mv "$tmp" "$settings"
          rm -f "$tmp.base"
        ' "$HOME/.claude/settings.json"
      '';

      # Private tooling that shouldn't live in the public rice.
      programs.zsh.initContent = lib.mkAfter ''
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
}
