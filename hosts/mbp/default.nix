# mbp — Julien's machine. The personal layer on top of the nebelhaus rice:
# identity, private apps, secrets. Everything else lives in the public modules.
{
  config,
  username,
  pkgs,
  ...
}:

let
  # The one place the org's name is typed. `haus.git.org` (set below) drives
  # every gh-dash section filter, rendered by the rice; this alias lets the
  # repoPaths further down — this machine's checkout layout, which is not the
  # rice's business — follow the same word instead of repeating it. Bound out
  # here because inside `home-manager.users.<user>` the `config` in scope is
  # home-manager's, which has no haus.* on it.
  ghOrg = config.haus.git.org;
in

{
  # ---- identity ----
  haus.git.name = "Julien Martel";
  haus.git.email = "julienbmartel@gmail.com";
  haus.git.signingKey = "6F7BD6F43A7C1420";
  # Select the Developer ID by SHA so the generated launch-agent script does not
  # contain the certificate holder's legal name. The resulting Developer ID
  # signature still anchors its designated requirement to the stable team OU.
  # Refresh with `security find-identity -v -p codesigning` after cert renewal.
  haus.pounce.signingIdentity = "4D2693E75A214534ACE299861AE7FC3086573136";

  # Windows-style "closing the last window closes the program" — macOS keeps a
  # windowless app running, and on this machine that is always a ⌘Q I forgot.
  # It's the same Quit event ⌘Q sends, so unsaved work still puts its sheet up.
  #
  # `exclude` REPLACES pounce's default rather than extending it, so Finder is
  # listed here explicitly — quit it and the desktop blinks out while it
  # relaunches. The rest are the apps on THIS Mac that keep doing real work with
  # no window open, which is the one case where "no windows" doesn't mean "done
  # with it":
  #
  #   OrbStack     the Docker case — closing the dashboard would stop the VM and
  #                every container in it
  #   ProtonVPN    the tunnel outlives its window; quitting drops it
  #   Chrome       windowless is a resting state, not an exit: downloads,
  #                extensions, and the browser-automation session an agent drives
  #   Notion Cal   lives in the menu bar for the next meeting and its alerts
  #   Slack        kept running for notifications, not for its window
  #   Legcord      ditto (Discord)
  #   ChatGPT      its global hotkey dies with it
  #   Cap, Loom    an upload finishing after the recording window closed
  #
  # Only .regular apps are candidates at all — pounce's census walks those and
  # skips accessory ones — so AeroSpace, Espanso, Dropover, Elgato, perch and
  # pounce itself need no entry. Tailscale is accessory today too and is listed
  # anyway: that's upstream's packaging choice, not a promise, and dropping the
  # mesh would be a bad way to find out it changed.
  haus.pounce.autoQuit = {
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
      "com.openai.codex"
      "so.cap.desktop"
      "com.loom.desktop"
    ];
  };

  # Editor: Helix (hx) everywhere. $EDITOR/$VISUAL are hx by default; the "Nix
  # Config" palette/bar action opens ~/.config/nix in a new Helix terminal tab
  # (hearth.guiEditor now defaults to "hx"), and the file-association hijack
  # routes double-clicked json/md/ts/… to Helix too. No Cursor anywhere.
  haus.hearth.hijackFileAssociations = true;

  # gh-dash: the review-queue half of the agent HUD. The statusline/bar HUD
  # answers "what are my panes doing"; this answers "what is waiting on ME" —
  # holt reads the worktree registry (parked sessions, wip commits, unpushed
  # branches), gh-dash reads GitHub (PRs, CI, reviews), and a branch that was
  # never pushed is invisible there on purpose. This one switch buys the patched
  # binary, the nebelung theme, ⌘G's borderless full-window overlay — and, now
  # that `git.org` is set, the tab strip itself: open / green / red / shipped,
  # rendered by hearth from that one word. What stays mine down in
  # programs.gh-dash.settings is only what describes THIS machine — where the
  # checkouts live, which key runs holt, how wide the columns are.
  haus.hearth.ghDash.enable = true;
  # The owner the review queue is about. One word, because an org rename would
  # otherwise be four search filters and three repo globs — and it silently
  # renders empty tabs rather than failing, which is the worst way for a
  # dashboard to be wrong.
  #
  haus.git.org = "hausfold";

  # ---- coding agents ----
  # Codex on top of the rice's default pair. There is an authed account and a
  # session history under ~/.codex, but no `codex` on PATH — it was installed
  # outside Nix once and went away, which is exactly the state that made
  # `agents.default = "codex"` a dead pane rather than an error. Listing it
  # here is what installs it; `agents.default` is asserted to be a member, so
  # switching the default is now a rebuild-time decision, not a discovery.
  haus.agents.clients = [
    "claude"
    "codex"
    "opencode"
  ];
  haus.agents.default = "claude";

  # ---- text expansion ----
  # The old Raycast "@@" snippet, now a rice option (haus.snippets → espanso
  # via the Espanso.app cask). Runs the SIGNED app bundle, not a nix-store binary,
  # so the one-time Accessibility grant survives reboots + nixpkgs bumps and the
  # espanso troubleshooting window stops popping up at login.
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
  # Accent: sapphire instead of the rice default (mauve). Machine-local — the
  # palette itself is unchanged; this just picks which whiskers hue everything
  # keys off. What it does and doesn't recolour is pinned by the rice's
  # `accent-reach` check, not by memory.
  haus.theme.accent = "pink";

  # The "orbits" Nebelung wallpaper (palette rings on a dark base).
  haus.theme.wallpaper = "orbits";

  # Stylus, force-installed into Zen through Firefox's enterprise-policy file.
  # This one line replaces the hand-rolled policies.json + announce-activation
  # pair that used to live down in the home-manager block: the rice owns both
  # now, and — the reason it exists at all — it stamps nebelung's userstyle
  # bundle with the accent above. Without that, the accent reaches Zen's own
  # chrome but never the web: github.com and youtube.com are styled by
  # Catppuccin userstyles living inside the extension, whose accent var
  # defaults to mauve and which no stylesheet can reach. Importing stays a
  # click (Stylus ▸ Manage ▸ Import); activation says so when there's a new
  # bundle. See hausfold#208.
  haus.zen.extensions.stylus = { };

  # ---- motion ----
  # Snappy macOS: the Dock's slide and Mission Control's zoom shortened, the
  # launch bounce gone, minimise scaling instead of the genie, and AppKit's
  # window open/close fade off — five keys the rice leaves alone by default
  # (hausfold#286). This is the opt-in.
  #
  # NOT `System Settings ▸ Accessibility ▸ Reduce motion`, which would cover the
  # same ground and more but is also the one flag every browser maps to
  # `prefers-reduced-motion: reduce` — and sites whose scroll-reveal animation
  # is what makes the content visible then never show it. These five keys are in
  # com.apple.dock and NSGlobalDomain and move no accessibility flag;
  # `hausax | jq .reduceMotion` stays false.
  #
  # Tradeoff I'm accepting here: it doesn't undo. Setting this back to "system"
  # only stops the rice WRITING the keys — a `defaults` write is sticky and
  # macOS keeps no memory of the values that were there before, so going back
  # means naming them here by hand (they're mkDefault, so a plain value wins) or
  # a `defaults delete`. Fine on this machine: it had never set any of them.
  haus.animations = "fast";

  # ---- desktop ----
  # No icons on the desktop. The files stay in ~/Desktop — this only stops Finder
  # from drawing them, so the wallpaper (and whatever prowl tiles on top of it) is
  # all that's ever behind the windows. Side effect of the same switch: the desktop
  # is no longer clickable, so clicking through to bare wallpaper doesn't activate
  # Finder any more. The rice's own finder defaults (den) don't touch this key, so
  # nothing to override — plain assignment.
  system.defaults.finder.CreateDesktop = false;

  # ---- trackpad ----
  # No tap-to-click — a physical press is the only click. Tapping fires stray
  # clicks while a palm rests on the pad mid-type. Both keys are needed: the
  # built-in pad reads AppleMultitouchTrackpad, an external Magic Trackpad reads
  # the Bluetooth domain, and nix-darwin's `trackpad.*` writes both.
  system.defaults.trackpad.Clicking = false;

  # Obsidian stores its theme per vault. Keep the notes vault on the full
  # Nebelung theme and retire the old palette-only CSS snippet.
  haus.hearth.obsidianVaults = [
    "Library/Mobile Documents/iCloud~md~obsidian/Documents/notes"
  ];

  # ---- everything this machine has ----
  # ONE list. It used to be three — this roster (launcher keys + install), plus
  # homebrew.casks/brews and home.packages — so an app was declared twice and
  # every entry carried a `cask = null` whose only meaning was "declared over
  # there instead". Now each entry names its own source, and WHICH FIELDS it
  # sets is what the entry means:
  #
  #   key         → on the Caps-Lock launcher + the pounce cheatsheet
  #   neither     → just installed: nothing bound, nothing drawn
  #   cask / brew / package / appStoreId → where it comes from
  #
  # Which AeroSpace workspace an app owns is no longer a field here at all —
  # haus.workspaces below claims it, by naming the app in `apps`
  # (notes/options-roadmap.md §5.4 in the workshop repo: promoted workspaces
  # to a real option so one can hold more than one app, and inverted
  # ownership so the workspace says so instead of the app).
  #
  # `order` only sorts the launcher half (cheatsheet rows, pill row), so the
  # install-only entries below leave it at its default.
  haus.roster = {
    # ---- the launcher ----
    # ghostty isn't here: den declares its name + cask, prowl its key +
    # workspace membership + icon + label, and every one of those defaults is
    # what I'd have typed. An entry only appears below where I want something
    # the rice didn't already decide — which is why zen is one line.
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
      # Paid App Store app. mas cannot purchase, so appStore.install (off
      # below) would skip it with a warning — the id is here to record what to
      # buy back on a fresh machine, not to promise an unattended install.
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
    # No trill: the rice made haus.trill.enable opt-in on 2026-08-04 (its
    # development is frozen) and this machine took the offer. `m` / workspace M
    # are free again — the roster entry was only trill's tiling half, so it went
    # with the app. Restoring it means both: the option true AND this entry back.
    swather = {
      order = 70;
      key = "h";
      name = "Swather";
      appId = "com.swather.app";
      label = "Swather";
      # No source field: I installed this one by hand, so nothing declares it.
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
    chatgpt = {
      order = 110;
      key = "x";
      name = "ChatGPT";
      appId = "com.openai.codex";
      label = "ChatGPT";
      cask = "chatgpt";
    };

    # ---- apps I don't launch by keyboard ----
    # No key → no leader letter, no cheatsheet row, no pill. Still declared,
    # which with homebrew.cleanup = "zap" below is the whole difference between
    # "installed" and "deleted on the next rebuild".
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
    # Free, so it's the one App Store app mas could actually fetch on its own
    # if appStore.install were ever turned on.
    xcode = {
      name = "Xcode";
      appStoreId = 497799835;
    };

    # ---- not apps at all ----
    # Fonts and CLIs have no bundle, no window, no icon, so every launcher field
    # stays null and only the source is set. They live here anyway: the point of
    # one list is that nothing is declared somewhere else merely for not being
    # clickable.
    font-hack = {
      cask = "font-hack-nerd-font";
    };
    font-jetbrains-mono = {
      cask = "font-jetbrains-mono-nerd-font";
    };
    gcloud-cli = {
      cask = "gcloud-cli";
    };
    # Also sill's, when the calendar pill is on — same id, so the definitions
    # merge instead of installing it twice.
    ical-buddy = {
      brew = "ical-buddy";
    };
    gogcli = {
      brew = "gogcli";
    };
    # The CLI only — haus.appStore.install stays off and masApps is
    # intentionally unused (see the note there), so this is for `mas list` /
    # `mas upgrade` by hand.
    mas = {
      brew = "mas";
    };
    gemini-cli = {
      # No agents.clients entry: gemini isn't a `wt` client, just a package.
      package = pkgs.gemini-cli-bin;
    };
    # Claude Code is deliberately NOT here — the rice installs it from
    # haus.agents.clients, and the overlay below is what makes that copy
    # the patched one. A second derivation shipping bin/claude would collide in
    # the same profile.

    # ---- system scope ----
    # environment.systemPackages rather than my user profile: on PATH for root,
    # for launchd jobs, and for non-login shells.
    biome = {
      package = pkgs.biome;
      scope = "system";
    };
    bench = {
      # Stays user-scope (the default): it's my tool, and the per-user profile
      # is already on PATH for scripts and non-login shells.
      # The workshop CLI (~/code/workshop): status / try / ship / rebuild for
      # the whole rice family. A real command on PATH (not an alias) so it works
      # from scripts, other shells, and non-interactive contexts; `bench try
      # switch` supersedes rebuild-pounce (it overrides ALL the local checkouts,
      # not just pounce).
      package = pkgs.writeShellScriptBin "bench" ''exec "$HOME/code/workshop/bench" "$@"'';
    };
  };

  # Which AeroSpace workspace each launcher app owns, its pill and its ⇧-throw
  # key. One app per workspace here, same as before the schema moved this off
  # the roster — nothing on this machine wants a role/project workspace with
  # several apps yet, but the shape is there when something does (see
  # haus.workspaces' own docs). Every key below matches the app's own
  # roster `key`, uppercased for the workspace id, same convention `add-app.sh`
  # uses.
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
    H = {
      key = "h";
      # Swather has no app-font glyph — fa-hourglass (U+F254) in the Nerd Font.
      icon = builtins.fromJSON ''"\uf254"'';
      apps = [ "swather" ];
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
    X = {
      key = "x";
      icon = ":codex:";
      apps = [ "chatgpt" ];
    };
  };

  # Non-app leader actions. Tap Caps (the leader), then Return → Things3's Quick
  # Entry panel. The app roster above maps letters → open an app; this maps a key
  # → a command, for actions that aren't "launch an app". `enter` is free in launch
  # mode (the rice asserts it doesn't collide with a roster letter or a built-in).
  haus.keys.leaderExtras = [
    {
      key = "enter";
      command = "osascript -e 'tell application \"Things3\" to show quick entry panel'";
      caption = "Things Quick Entry";
    }
  ];

  # Fully declarative Homebrew: a rebuild uninstalls (and zaps the data of) any
  # cask/brew not declared above. Every app I keep is now listed, so the only
  # thing this reaps is genuine cruft. Adding an undeclared app by hand and
  # forgetting to list it means it's gone on the next rebuild — that's the deal.
  haus.homebrew.cleanup = "zap";

  # Keep declared casks current on THIS machine (rice default stays off, so the
  # rest of the family keeps reproducible rebuilds). upgrade → a rebuild upgrades
  # outdated casks instead of pinning to whatever brew first installed; autoUpdate
  # → `brew update` first so it sees the newest versions. Together: date-released
  # casks track upstream latest instead of freezing at whatever brew first
  # installed. Tradeoff I'm accepting here: my rebuilds chase upstream latest
  # and aren't perfectly reproducible.
  haus.homebrew.upgrade = true;
  haus.homebrew.autoUpdate = true;

  # Install casks without the com.apple.quarantine xattr. These are notarized
  # apps I curated in homebrew.casks; the quarantine flag only gates a one-time
  # Gatekeeper first-launch prompt. Most casks prompt once, but ChatGPT relaunches
  # a nested quarantined helper (its "computer use" sub-app) by path, so macOS
  # re-prompted on EVERY launch. Sparkle self-updates never set the flag — only
  # Homebrew did — so stripping it at install kills the prompt for good. Tradeoff:
  # skips the first-launch notarization check for casks (signature enforcement +
  # XProtect still apply).
  #
  # Delivered as HOMEBREW_CASK_OPTS, not `homebrew.caskArgs.no_quarantine`:
  # Homebrew 6 dropped `--no-quarantine` as a `brew install` flag (the env var is
  # the only path left — see cask_opts_quarantine? in env_config.rb). caskArgs
  # writes `cask_args no_quarantine: true` into the Brewfile, and brew bundle
  # turns that into `brew install --no_quarantine`, which now aborts with
  # "invalid option" — so EVERY new cask install failed the whole `brew bundle`
  # step of a rebuild. Already-installed casks were unaffected, which is why this
  # only surfaced the first time a cask was added.
  homebrew.onActivation.extraEnv.HOMEBREW_CASK_OPTS = "--no-quarantine";

  # My personal SketchyBar pills, tuned atop the rice default: switch on the
  # agent-pane status paw (fed by the Claude hooks wired below), the Claude
  # usage gauge (5-hour · weekly, fed by the same statusLine the rice already
  # points at `claude-statusline`), the Elgato key light toggle, and the
  # caffeinate keep-awake controller; switch off the default-on weather and
  # wifi core pills.
  haus.sill.items = {
    agents = true;
    aiUsage = true;
    elgato = true;
    caffeinate = true;
    weather = false;
    wifi = false;
  };

  haus.sill.battery.hideOver = 80;
  haus.sill.clock.mode = "compact";

  # Keep both bars: the coupled workspace/front-app/leader side plus clock and
  # battery stay in the menu bar; media, hush and the personal controller/status
  # pills move to the second bar at the bottom. Pinning the menu bar to `top` is
  # load-bearing here: `auto` would put it on the bottom beside the second bar
  # whenever the Mac is docked.
  haus.sill.position = "top";
  haus.sill.bottom = {
    enable = true;
    items = {
      media = true;
      hush = true;
      agents = true;
      aiUsage = true;
      elgato = true;
      caffeinate = true;
    };
  };

  # Claude Code's global memory (~/.claude/CLAUDE.md) — how I like to work across
  # every repo. Personal, so it lives here in the host; the rice just provides the
  # haus.claude.globalMd plumbing (hearth writes the file when set). Keep it
  # short and universal — repo-specific rules belong in each project's own CLAUDE.md.
  haus.claude.globalMd = ''
    # CLAUDE.md — global

    Personal defaults for how I (julienmartel) like to work, across every repo. Kept
    deliberately short and universal — repo-specific detail lives in each project's own
    CLAUDE.md, not here.

    ## How to answer me

    Load the `brief` skill at the start of every session and follow its shape for the
    whole session: verdict first, ≤5 anchored steps, and escalate to me only at ≥3/5
    (my usual bar) with a recommendation and a reversal cost. It governs code work,
    research, and anything I paste. Say "drop brief" / "full mode" to turn it off. The
    skill itself lives at `~/.claude/skills/brief/SKILL.md`, an OUT-of-store symlink —
    edit `~/.config/nix/claude/skills/brief/SKILL.md` and the next pane has it, no
    rebuild. Same for the other three host-installed skills: `ship`, `park`, `handoff`.

    ## Working in a git worktree

    My super+a (`⌘A`) zellij hotkey spawns agent panes as `claude --worktree`:
    each session gets its own checkout on a `worktree-<name>` branch, branched from the
    repo's local HEAD, living OUTSIDE the repo (under `~/.cache/claude-worktrees/`). The
    `WorktreeCreate`/`WorktreeRemove` hooks are wired globally, so **any** repo I open can
    be worktree'd — not just nebelhaus.

    **Detect it:** `git rev-parse --git-common-dir` points outside your toplevel → you're
    in a linked worktree.

    **Etiquette when you're in a worktree** (i.e. the detection above says you are):
    - **Committing, pushing, and opening the PR are standing permission — just
      do all three, never ask first.** The default answer to "want me to commit
      / push / open a PR?" is always yes, so don't ask the question — do the
      work and report the PR link. The ONLY thing that waits for me is *merging*
      the PR (see below); everything up to and including "PR is open" is yours to
      drive unprompted, in default mode. A verified change left uncommitted,
      unpushed, or without a PR is an unfinished task, not a finished one.
    - Commit on your `worktree-*` branch as usual.
    - **Building/verifying is always allowed — you have standing permission, in
      default mode, to build without asking.** A build (`nix build`, a project's
      own run/verify skill) is read-only toward every checkout and never
      activates anything, so it's exactly what a worktree is for — don't stop at
      "the diff is ready" when you could have built it. This holds even when the
      build compiles a **child** repo from a parent dir's worktree session: the
      child's checkout is only read, not mutated, so go ahead. Only *activation*
      — anything that switches this machine's running state, `darwin-rebuild
      switch` and the wrappers around it — stays off-limits **to you** from a
      worktree. Not because worktree code is unsafe to activate (I do it myself,
      routinely, to feel one branch alone), but because activation is
      machine-wide and serial: five parallel agents each with a good reason to
      switch would silently overwrite one another. So build, then hand me the
      exact command to run from a pane in your worktree and let me run it. Where
      a repo's own tooling enforces this, it refuses you by name and its
      refusal/CLAUDE.md names the override — if I've explicitly asked you to
      activate, use that override rather than asking again.
    - **Pushing already-committed work is fine from a worktree.** You have my
      standing permission, in default mode, to run a repo's push/ship step from
      a worktree without asking — it only pushes commits that already exist and
      never activates anything. (A repo's ship step may operate on the *main*
      checkouts to ripple merged/released work downstream; it does not push your
      unmerged `worktree-*` branch.)
    - **Land your work through a PR — never a direct push or a local `git merge`
      into `main`.** When the branch is ready, push it and open a PR (`gh pr
      create`) against `main`. Don't `git merge` your `worktree-*` branch into
      `main` yourself, don't push to `main` directly, and don't touch the main
      checkout's files — parallel agents pushing/merging straight to main have
      clobbered each other's commits, and a PR is conflict-detected and atomic,
      so nothing gets silently overwritten. Merging the PR is my call — but
      **"my call" means don't merge *unprompted*, not "never merge."** When I
      explicitly tell you to land it (`/ship`, "ship it", "merge and clean up"),
      that IS the go-ahead: merge with `gh pr merge` (still never a local merge
      or direct push — the PR's atomicity is the point). Absent that, stop at
      "PR open." Shipping isn't merging: a repo's ship step pushes committed
      state (and bumps locks), it never folds your branch into main.
    - **When I say ship/land/merge, `/ship` finishes the whole job** (see the
      ship skill): merge the PR, then clean up every worktree *this session*
      spun up — a session often hand-creates a sibling-repo worktree for
      out-of-repo work, and those aren't auto-reaped, so merge their PRs too and
      `git worktree remove` them. When it's all landed and nothing ≥3/5 needs my
      attention (don't wait on CI unless that's the point), `/ship` reports and
      stops. It does **not** close this pane or open a new one — I open and close
      my own panes (see "Don't drive my multiplexer" below). The current worktree
      isn't reaped here (you're still in it); it's cleaned up when I close the
      pane myself (the `holt` remove hook) or by a later `holt reap`.
    - When done, push the branch, open the PR, and — if I didn't say ship — tell
      me the PR link. The worktree dies with the pane; the branch + PR survive
      until merged.

    This etiquette is worktree-specific. Sometimes I open a plain (non-worktree)
    session directly on `main` for a small one-off — usually when no worktrees are
    active. In that mode, working on and committing to `main` directly is fine and
    expected; the "don't touch main" and PR-to-land rules only bind when you're
    actually in a worktree — they exist to stop *parallel* agents from clobbering
    each other, which a lone editor on main can't do.

    ## How I ship

    **Ship by default, sized to the change — but only in repos I own solo** (my personal
    infra: the hausfold family, qnap-mediastack, ~/.config/nix, and the like). In shared or
    client repos, default to caution: prepare the change, then ask before pushing.

    In a solo repo:
    - **Small change** (bugfix, typo, config/theme tweak, version bump, docs): commit,
      verify, and ship in the same turn without asking. A verified fix left uncommitted,
      unpushed, or undeployed is a bug, not a finished task.
    - **Big or risky change** (new feature, refactor, anything hard to roll back, anything
      a user could feel break): verify it works, then stop and ask before shipping. Once
      approved, drive it all the way to shipped — don't stop at "the diff is ready."
    - **Releases / user-facing publishes are always gated.** Propose one after shipping
      user-facing changes, but never tag/publish unprompted.
    - When unsure which bucket a change is in, ask.

    ## Repos nested inside other repos

    Some of my solo repos live *inside* another checkout — e.g. the whole
    hausfold family (`nebelung`, `pounce`, `nebelhaus`, …) sits under the
    `~/code/workshop` dir, whose `.gitignore` lists each child. **That
    nesting is purely to keep the outer tree clean; each child is a full,
    independent repo I own solo.** So:

    - To change a child, `cd` into it and commit / push / ship it under its own
      rules and the ship-by-default policy above. A child being gitignored *by
      the parent* says nothing about committing *inside the child* — that's a
      different repo, and it is NOT a signal that git ops there are risky or
      need extra confirmation.
    - When I ask for a cross-repo flow from the main checkout — merge the open
      `worktree-*` PRs, sync locks, rebuild, ship — run it end-to-end. Land each
      branch by merging its **PR** (`gh pr merge`), never a local `git merge` +
      push to `main` — the PR is what stops two agents' branches from clobbering
      each other. Don't re-confirm each repo word-for-word. "Merging is my call"
      means don't merge *unprompted*, not "re-ask after I've told you to."

    ## Don't drive my multiplexer

    **Don't open or close zellij panes/tabs for me — mostly.** I manage my own
    panes: opening a pane, spawning a "landing" pane, or closing the one you're
    in is obtrusive and I don't want it as a default (it's how `/ship` used to
    end — that's gone). If a task genuinely needs a pane (e.g. I explicitly ask
    you to launch something in one), ask first or tell me the command to run
    myself. When you need to do a main-checkout-only thing from a worktree (like
    activating after a ship), `cd` to the main checkout and run it in place —
    don't spawn a pane to carry it.

    ## How I verify

    **Verify by actually running it**, not by eyeballing the diff. Testing in prod is
    acceptable house style for my personal infra — build it, run it, observe the real
    behavior. Prefer a project's own run/verify skill if it has one.

    ## Keeping docs honest

    If you find something in a CLAUDE.md, README, or docs file that's wrong or stale, fix
    it in the same change — don't just work around it. Keep these files short; push detail
    into the matching docs file rather than growing the top-level one.
  '';

  # ---- Claude Code, patched, as an OVERLAY rather than a package ----
  # The rice installs the clients named in `haus.agents.clients` and
  # references `pkgs.claude-code` to do it. So this cannot be a second
  # derivation in home.packages, where it used to live: two builds shipping
  # `bin/claude` collide in one profile. Redefining `claude-code` itself means
  # the rice's own reference resolves to the patched build, there is exactly
  # one `claude` on PATH, and any future consumer of `pkgs.claude-code` inherits
  # the patch for free. `useGlobalPkgs` is on, so this reaches home-manager too.
  #
  # Three annoyances Claude Code has no settings for:
  #
  # 1. The permission-mode footer line ("⏵⏵ auto mode on (shift+tab to
  #    cycle)") under the custom statusline — with 4 panes per tab those
  #    rows add up. declutter-claude-footer.py patches the JS source
  #    embedded in the bun-compiled binary so the line renders as null;
  #    same for the right-hand chip strip ("/rc · focus", IDE selection,
  #    PR status), a SIBLING row that survived the first collapse and
  #    came back as a permanent second line in CC 2.1.220. Its regexes
  #    pin code structure, not minified names, and FAIL THE BUILD (a
  #    match count off its expected value) if a claude-code update
  #    reshapes the footer — so a bump can break here; see the script
  #    header for how to re-derive. autoSignDarwinBinariesHook re-signs the patched
  #    Mach-O during fixup (unsigned = SIGKILL on Apple Silicon), and
  #    the package's own versionCheckPhase proves the result still runs.
  #
  # 2. Having collapsed that row, the rice statusline is now the ONLY
  #    place the permission mode appears — and the statusline payload
  #    doesn't carry it, so the mode chip had to be read out of the
  #    session transcript, where the mode is only stamped at turn
  #    boundaries. Result: a chip that sits still while you cycle
  #    shift+tab. statusline-permission-mode.py adds `permission_mode`
  #    to the payload (the builder already takes the live mode as a
  #    parameter; it just never emitted it), paying for the bytes out
  #    of a version banner inlined at the same site. Same
  #    same-length/fail-loud rules as above. The rice keeps its
  #    transcript fallback, so this is an upgrade, not a dependency.
  #
  # 3. The hard-coded sleep blocker: on macOS the agent silently spawns
  #    `caffeinate -i -t 300` (renewed while it works). Shadow
  #    caffeinate with a no-op on claude's PATH only — everything else,
  #    including pounce's caffeinate command, still gets the real
  #    /usr/bin/caffeinate. Sleep stays manual.
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
          # platform list the rice's agents.clients assertion reads and the
          # license the unfree check reads. Carry the real one through.
          inherit (prev.claude-code) meta;
        };
    })
  ];

  # The tap pear-desktop comes from. Taps are the one Homebrew thing the roster
  # doesn't model — a cask names its tap inline (see pear-desktop above), but
  # the tap itself still has to be registered once.
  homebrew.taps = [ "pear-devs/pear" ];

  # No homebrew.casks / homebrew.brews / home.packages list down here any more:
  # every one of those entries moved into haus.roster above, which is the
  # point of the change. The rice's own modules still contribute their casks
  # (ghostty, aerospace, sketchybar, espanso) — those aren't mine to list.

  # The App Store stays manual on this machine (haus.appStore.install is
  # off by default). What that costs, precisely, having checked it against
  # mas 7 rather than assuming:
  #   • mas has no `signin` — sign in once in App Store.app, per machine.
  #   • mas CANNOT buy a paid app, ever. Things (904280696) is a purchase.
  #   • mas CAN fetch a free app it's never seen: `mas get` works for Xcode
  #     (497799835). (`mas install` is the narrower one — already-purchased
  #     only — and is what the old note here conflated it with.)
  #   • Both need root since macOS 13, which is exactly why homebrew.masApps
  #     hangs: brew bundle runs `mas install` as me, mas stops for a password,
  #     and a rebuild has no terminal to show it in. The rice's activation path
  #     is already root, so turning appStore.install on would work — I just
  #     don't want a rebuild touching my Apple ID.
  # System Settings → App Store → automatic updates keeps them current.

  # ---- personal home layer: extra packages, private git config, secrets ----
  home-manager.users.${username} =
    {
      config,
      lib,
      pkgs,
      osConfig,
      nebelung,
      ...
    }:
    let
      # ---- pounce: opt-in command plugins ----
      # pounce's optional plugins (pkgs/pounce-commands/optional) ship OFF —
      # each assumes a tool, a service or an account. The rice installs
      # pounce-commands with the default `plugins = []`, so turning one on is
      # the host's job. This list IS the switch; everything below is plumbing.
      #
      #   audio       switch sound output / input device
      #   bluetooth   connect & disconnect paired devices (AirPods…)
      #   caffeinate  keep the Mac awake (also what the sill caffeinate pill drives)
      #   docker      start / stop / restart containers, tail logs (OrbStack here)
      #   github      jump to my PRs, review requests, issues, repos
      #   perplexity  type a question → a fresh perplexity.ai thread in the browser
      #   spotify     play / pause / skip / shuffle, copy song link
      #   ssh         pick a host from ~/.ssh/config and connect
      #   tailscale   connect toggle, copy my / any peer's tailnet IP
      #
      # Their CLI deps (switchaudio-osx, blueutil, gh) already come from the
      # rice, which adds pounce-commands.allPluginDeps to the profile whether
      # or not a plugin is enabled — so nothing here has to carry them.
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

      # One store copy of pounce-commands built with exactly those plugins. We
      # symlink the individual scripts out of it (below) rather than adding the
      # package to home.packages, which would collide with the rice's own
      # pounce-commands on every shared command filename.
      pouncePluginPkg = pkgs.pounce-commands.override { plugins = pouncePlugins; };

    in
    {
      # home.packages lives in haus.roster now (gemini-cli, orbstack, bench —
      # `scope = "user"` puts them right back here). One list for what this
      # machine has, whether it's a cask, a formula or a Nixpkgs package.

      # Dev loop for hacking on pounce: rebuild the system against the LOCAL
      # pounce checkout (picks up uncommitted edits) instead of the pinned
      # github input. Normal `darwin-rebuild` still uses github → reproducible.
      # When happy: commit + push pounce, then a plain rebuild pins the new rev.
      programs.zsh.shellAliases.rebuild-pounce = ''
        (cd "$HOME/.config/nix" \
          && nix build .#darwinConfigurations.mbp.system \
               --override-input nebelhaus/pounce "path:$HOME/code/workshop/pounce" \
          && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp)
      '';

      # The enabled plugins (see pouncePlugins above), dropped into
      # ~/.config/pounce/commands — the last and highest-precedence dir pounce
      # discovers at runtime, so an enabled plugin behaves exactly like a
      # built-in and is still shadowable by a hand-written script of the same
      # name. xdg.configFile rather than home.file for the same reason the rice
      # uses it: a dynamic attrset can't merge with the static
      # `home.file."…".source` attr-paths in this file.
      #
      # Declarative on purpose. This dir spent months holding these same eight
      # scripts as HAND-MADE symlinks into ~/code/workshop/pounce, and all
      # eight went dangling the day that checkout moved to ~/code/workshop —
      # silently, because a command whose file won't read simply doesn't appear
      # in the palette. Nothing announced the loss; the rows just stopped being
      # there. Store paths can't rot that way.
      xdg.configFile = lib.listToAttrs (
        map (
          p:
          lib.nameValuePair "pounce/commands/${p}.sh" {
            source = "${pouncePluginPkg}/share/pounce/commands/${p}.sh";
          }
        ) pouncePlugins
      );

      # …and reap what the old hand-made symlinks left behind. Any dangling
      # link in that dir is by definition a plugin pointing at a checkout that
      # moved or went away, and home-manager REFUSES to link over an existing
      # unmanaged path — so without this the first rebuild after this lands
      # dies on eight "would be clobbered" errors. Ordered before
      # checkLinkTargets (home-manager's own collision check) so it runs early
      # enough to matter. Only ever removes BROKEN links: a real file or a live
      # symlink someone put there on purpose is left alone.
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

      # Text expansion moved up to haus.snippets (darwin level) — the rice
      # option now owns espanso, via the signed Espanso.app cask.

      programs.git.settings = {
        http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
        core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      };

      # ---- gh-dash: my half of it (see haus.hearth.ghDash above) ----
      # Everything generic now lives in the rice, behind
      # `haus.hearth.ghDash.enable` (set at the top of this file): the
      # patched binary wearing the house mark, the nebelung `include:` in the
      # active flavor/accent, the `catppuccin.gh-dash.enable = false` opt-out,
      # the roster entry, the ⌘G borderless zellij overlay — and, since
      # `git.org` is set up there, the three section lists themselves. The tabs
      # used to live here; they were never personal, only org-shaped, and
      # hearth renders exactly the same four PR tabs from the owner name.
      #
      # What's left below is the part that genuinely could never be shipped to
      # anyone else: where my checkouts sit on disk, which keys run which local
      # command, and the column widths of a laptop screen. Any of the rice's
      # lists can still be replaced wholesale from here — they're mkDefault —
      # but replacing one means restating that whole list, since gh-dash reads
      # a section list as a unit.
      #
      # `programs.gh.enable` is false here, so home-manager's gh-extension
      # registration is a no-op — the manually installed `gh dash` extension
      # keeps working and reads this same config file, and `gh-dash` is on PATH
      # from the store as well. Either entry point, one config.
      programs.gh-dash = {
        settings = {
          defaults = {
            view = "prs";
            prsLimit = 20;
            issuesLimit = 10;
            notificationsLimit = 20;
            # A dashboard that's half an hour stale isn't one. Six calls an
            # hour against a 5000/hr token budget is free.
            refetchIntervalMinutes = 5;
            prApproveComment = "LGTM";

            # Off by default: on a laptop the preview eats half the width and
            # the table IS the answer for "what's open". `p` toggles it, and
            # that's when you want the CI/checks detail anyway.
            preview = {
              open = false;
              width = 0.45;
              height = 0.6;
              position = "auto";
            };

            # Minimal on purpose. ColumnConfig only carries width + hidden
            # (there's no grow/align in the schema), so the layout is: kill the
            # columns that are constant for a solo org, let `title` take the
            # slack.
            #   author/authorIcon — this is a solo org today; repo + title still
            #     identify the occasional bot-owned row without spending two
            #     columns on the same face/name everywhere else.
            #   base — always main.
            #   labels/assignees/createdAt — noise I never act on.
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

          # Commands BLOCK the TUI until they exit — gh-dash hands them to a
          # shell and waits. So these are things I *want* to take over the pane
          # until I'm done (holt, lazygit); nothing long-running and unattended
          # like `bench try`.
          #
          # ---- keys chosen from what's actually FREE, the hard way ----
          # gh-dash checks custom keybindings BEFORE every built-in
          # (`isUserDefinedKeybinding` is the first case in ui.go's key switch),
          # and it does NOT warn when a custom key shadows a built-in one. It
          # just silently wins, and `?` then lists BOTH bindings for the same
          # key. All three of the original keys here were collisions:
          #
          #   w → shadowed "watch checks", the one built-in that turns a PR row
          #       into a live CI watcher. Now `H`, for holt.
          #   g → shadowed "first item". Now `z` — free, unshifted, and the vim
          #       `g` is back.
          #   y → shadowed "copy number" AND duplicated a built-in: `Y` already
          #       copies the URL, natively and instantly. The custom one shelled
          #       out to `gh pr view` for it, which blocks the TUI on an API
          #       round-trip to learn a URL gh-dash already has. Deleted, not
          #       moved; `Y` is the binding.
          #
          # Free keys left, if this list ever grows: b f i n, and most capitals
          # (B D E F I J K M N O S T U Z). Everything else in the PRs view is
          # taken by a built-in — check keys.go and prKeys.go before adding one,
          # because nothing else will tell you.
          keybindings.prs = [
            {
              # Jump into the agent session behind this PR. holt names a
              # worktree after the branch minus the `worktree-` prefix, and
              # resumes whichever client made it (claude/codex/opencode).
              # Rebuilds the checkout first if the session was parked.
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

          # Where the owner's repos are checked out — the half of the queue the
          # rice can't know, since it's a filesystem layout rather than a
          # GitHub fact. Exact keys beat the wildcard, so `workshop` and
          # `.github` (checked out as org-profile) can sit next to the
          # `${ghOrg}/*` fallback that covers every other family repo,
          # including ones that don't exist yet. Drives {{.RepoPath}} above and
          # gh-dash's own checkout/diff.
          #
          # ghOrg, not a literal: these globs and the rice's section filters
          # have to name the same owner or the tabs list PRs whose rows can't
          # be opened locally, so they read one option (see the top of this
          # file).
          repoPaths = {
            "${ghOrg}/*" = "${config.home.homeDirectory}/code/workshop/*";
            "${ghOrg}/workshop" = "${config.home.homeDirectory}/code/workshop";
            "${ghOrg}/.github" = "${config.home.homeDirectory}/code/workshop/org-profile";
            "JulienMartel/nix-config" = "${config.home.homeDirectory}/.config/nix";
          };

          # No `repo:` block: those two intervals only feed the flagged repo view
          # (see ghDashPkg above for why it isn't on), so setting them here would
          # be config for a screen that can't be reached.

          # delta is already themed by the rice (hearth wires the nebelung
          # delta port into gitconfig), so diffs match everything else.
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

      # Claude Code — my personal "brief" answer-shape skill: verdict first, ≤5
      # anchored steps, escalate only at ≥3/5 with a recommendation + reversal cost.
      # The stanza in haus.claude.globalMd above is what makes it load every
      # session; this just puts the skill on disk. Symlinked OUT of the nix store
      # (mkOutOfStoreSymlink) so editing SKILL.md is live in the next pane with no
      # rebuild — its tables (time estimates, the always-≥3/5 list) get tuned often.
      # Reproducible on a fresh machine: the target is in THIS repo, which always
      # lives at ~/.config/nix.
      home.file.".claude/skills/brief".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/brief";

      # Claude Code — my generic "ship" skill (the repo-agnostic fallback: PR →
      # merge → clean up → report; never opens/closes a zellij pane). Repos with
      # their own scoped ship skill win over this one. Same out-of-store symlink
      # pattern as brief, for the same reason (edit SKILL.md, live next pane).
      # NOTE: on the FIRST rebuild after this lands, remove the old hand-placed
      # dir so the symlink can take over — `rm -rf ~/.claude/skills/ship` — since
      # there's no home-manager backupFileExtension to move it aside.
      home.file.".claude/skills/ship".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/ship";

      # Claude Code — "/park": set the working tree aside as a `wip:` commit via
      # `wt park`, never `git stash`. The stash stack lives in the shared .git dir,
      # so every agent worktree of a repo AND the main checkout pop the same one —
      # parallel agents have popped each other's entries into trees that never asked
      # for them. The rule is in my global CLAUDE.md; this skill is the door an agent
      # actually walks through, and covers `/unpark` (including its refusal to rewind
      # an already-pushed wip commit). Same out-of-store symlink pattern as above.
      home.file.".claude/skills/park".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/park";

      # Claude Code — "/handoff": turn a paste (or this session) into a
      # self-contained prompt for a COLD agent, put it on the clipboard, and
      # print it between begin/end markers so it's findable in a wall of
      # transcript. Lives here rather than in the rice because it's about how I
      # move work between panes, not about the desktop the rice builds — same
      # bucket as brief/ship/park. Out-of-store symlink for the same reason
      # again: the prompt template is the part that gets tuned, and tuning it
      # shouldn't cost a rebuild.
      home.file.".claude/skills/handoff".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/handoff";

      # Claude Code — reinstate our hooks in settings.json on every rebuild.
      #  • WorktreeCreate/WorktreeRemove: `Super a` / ⌘A (rice: hearth/zellij)
      #    spawns `claude --worktree`; these hand the create/remove off to `holt`
      #    so worktrees land under ~/.cache/claude-worktrees instead of inside the
      #    repo — and so closing a pane never loses uncommitted work (holt parks
      #    it on the branch first) and stays resumable (`holt` to list, `holt
      #    <name>` to reopen). holt is its own repo now, taken by the rice as a
      #    flake input and shipped on PATH; we just point the hooks at its system
      #    path here (Claude owns settings.json, so hook wiring is the host's job
      #    — same as the sketchybar hooks below).
      #    These said `wt create` / `wt remove` until now, which was a live
      #    revert waiting to happen: settings.json had already been repointed at
      #    holt BY HAND, and this activation runs on every rebuild, so the next
      #    `haus rebuild` would have quietly put frozen `wt` back in the loop.
      #    Note the subcommand differs — `holt hook create`, not `holt create`.
      #  • UserPromptSubmit/Notification/Stop/SessionEnd: feed the `agents` bar
      #    paw (haus.sill.plugins) — each fires agents-hook.sh from inside the
      #    agent's pane, self-reporting its state (working/waiting/idle) + subscribe
      #    target. Personal because it points at the sketchybar plugin path.
      # All of it lives in the host, NOT the generic rice (the rice's pathless
      # claudeCodePermissionMode correctly stays there). Same jq-merge-only-our-keys,
      # never-own-the-file trick — Claude rewrites settings.json as grants/plugins
      # change, so we preserve the rest. jq is pinned from the store because
      # activation runs with a bare PATH.
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

      # Claude Code — pre-approve the commands auto mode keeps escalating to a
      # prompt. The rice's claudeCodePermissionMode sets defaultMode = "auto":
      # edits + safe reads run unattended, but `gh …`, `git worktree add/remove`,
      # pushes and the like still stop for a yes/no — and those are exactly the
      # agent-worktree flow's bread and butter (wt, bench, and everyday git/gh).
      # So allowlist them here. Personal, NOT the public rice: how loose an
      # agent's leash is is a per-user call, and `git:*`/`gh:*` are broad. We
      # UNION into whatever grants Claude has already written (never clobber its
      # list) — same merge-our-keys / never-own-the-file trick as the hooks
      # above; auto mode's own background safety checks still apply on top.
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

      # Claude Code — personal UI preferences, pinned so they survive Claude's
      # own rewrites of settings.json.
      #   verbose = false — keep tool output collapsed to the short form; ⌃O
      #     still expands it for the current session, this just decides what
      #     every new session starts as.
      # The rice seeds the defaults it considers house style
      # (hearth: tui/statusLine/spinnerTips/…); this is the per-user layer on
      # top, hence host and not rice. Same merge-our-keys / never-own-the-file
      # trick as the two blocks above — and the same consequence: toggling this
      # from inside Claude (`/config`) lasts until the next `haus rebuild`,
      # which re-asserts the value below. Flip it here to change it for good.
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

      # Secrets + tooling that shouldn't live in the public rice.
      programs.zsh.initContent = lib.mkAfter ''
        export GEMINI_API_KEY="$(cat ~/.secrets/google-api-key)"
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
}
