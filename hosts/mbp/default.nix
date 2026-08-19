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
    # jcode (jcode.sh) — on trial. It is the one client that does NOT come from
    # nixpkgs: the AI room installs it from its own Homebrew tap and declares
    # that tap, which is why neither appears in this file any more. `ai.default`
    # stays claude until it has been driven for a while; naming it here only
    # installs it, writes its instructions and skill, and lights its rows in the
    # bar.
    "jcode"
  ];
  haus.ai.default = "jcode";

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

  # Accent-stamped userstyles in Zen (hausfold#208); import stays a click.
  haus.zen.extensions.stylus = { };

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

  # ---- trackpad ----
  # No tap-to-click: palm rests fire stray clicks mid-type.
  system.defaults.trackpad.Clicking = false;

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
    # No trill here: opt-in in the rice and left off, so `m` / workspace M are free.
    swather = {
      order = 70;
      key = "h";
      name = "Swather";
      appId = "com.swather.app";
      label = "Swather";
      # No source field: installed by hand.
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
    H = {
      key = "h";
      # No app-font glyph for Swather — fa-hourglass (U+F254) in the Nerd Font.
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
    page = true;
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
      # First on the left, and ahead of the agent readouts on purpose: it answers
      # WHERE this window is (which `T/<repo>` page), which is the question the
      # ones after it are all about — what my work is doing, and how much of it
      # has landed. It draws nothing outside the terminal pages, so on every
      # other workspace the left group simply starts at the paw.
      page = "left";
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

    Personal defaults for how I (julienmartel) like to work, across every repo, in
    whichever client the pane is running. Kept deliberately short and universal —
    repo-specific detail lives in each project's own AGENTS.md, not here.

    ## How to answer me

    Load the `brief` skill at the start of every session and follow its shape for the
    whole session: verdict first, ≤5 anchored steps, and escalate to me only at ≥3/5
    (my usual bar) with a recommendation and a reversal cost. It governs code work,
    research, and anything I paste. Say "drop brief" / "full mode" to turn it off. The
    skill body lives at `~/.config/nix/claude/skills/brief/SKILL.md` and is linked into
    both `~/.claude/skills/brief` and `~/.agents/skills/brief` (Codex and OpenCode read
    the second) as an OUT-of-store symlink — edit it and the next pane has it, no
    rebuild. Same for the other three host-installed skills: `ship`, `park`, `handoff`.
    If your client doesn't load skills at all, read the SKILL.md by path; it's plain
    markdown.

    ## Working in a git worktree

    My super+a (`⌘A`) zellij hotkey spawns each agent pane into its own worktree —
    Claude Code through its native `--worktree` flag, Codex and OpenCode through
    `holt new`, which produces the identical checkout from the outside. Either way the
    session gets its own checkout on a `worktree-<name>` branch, branched from the
    repo's local HEAD, living OUTSIDE the repo (under `~/.cache/claude-worktrees/` —
    the path name is historical, every client shares it). The lifecycle hooks are wired
    globally, so **any** repo I open can be worktree'd — not just haus.

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
      refusal (or the repo's AGENTS.md) names the override — if I've explicitly
      asked you to activate, use that override rather than asking again.
    - **Pushing already-committed work is fine from a worktree.** You have my
      standing permission, in default mode, to run a repo's push/ship step from
      a worktree without asking — it only pushes commits that already exist and
      never activates anything. (A repo's ship step may operate on the *main*
      checkouts to ripple merged/released work downstream; it does not push your
      unmerged `worktree-*` branch.)
    - **Don't sync with main unless you have to — and when you do, rebase.**
      GitHub merges a PR that's merely *behind* main; only a genuine conflict
      forces a sync, so most branches never need one. When one does: `git
      rebase origin/main`, then force-push. Rebase replays *your* commits onto
      main's tip — main's commits become the new base and are never re-resolved
      — so the cost is one resolution per commit on YOUR branch, not per commit
      on main; with my small PRs that's usually one. My `worktree-*` branches
      are single-agent and nobody bases on them, so rewriting them is free:
      "never rebase published history" doesn't apply here. Never `git merge
      origin/main` into a branch — it puts commits I didn't write in my PR's
      commit list. `flake.lock` is never hand-merged either way: take main's
      wholesale (`git checkout --theirs flake.lock`), then re-run `nix flake
      update <input>` if the branch genuinely needed a newer pin.
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
    hausfold family (`nebelung`, `pounce`, `haus`, …) sits under the
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

    If you find something in an AGENTS.md, CLAUDE.md, README, or docs file that's wrong or
    stale, fix it in the same change — don't just work around it. Keep these files short;
    push detail into the matching docs file rather than growing the top-level one.
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

  # Taps are the one Homebrew thing the roster doesn't model — but nothing here
  # needs one any more: `1jehuang/jcode` moved into the AI room, which declares
  # both the tap and the formula whenever `ai.clients` names jcode.

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

      # My four personal skills. The instructions above are what make `brief`
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

      # handoff — turn a paste (or this session) into a self-contained prompt
      # for a COLD agent, on the clipboard and between begin/end markers.
      home.file.".claude/skills/handoff".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/handoff";

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
      home.file.".agents/skills/handoff".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix/claude/skills/handoff";

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
