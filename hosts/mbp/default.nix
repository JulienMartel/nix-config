# mbp — Julien's machine. The personal layer on top of the nebelhaus rice:
# identity, private apps, secrets. Everything else lives in the public modules.
{
  username,
  pkgs,
  ...
}:

{
  # ---- identity ----
  nebelhaus.git.name = "Julien Martel";
  nebelhaus.git.email = "julienbmartel@gmail.com";
  nebelhaus.git.signingKey = "6F7BD6F43A7C1420";
  # Select the Developer ID by SHA so the generated launch-agent script does not
  # contain the certificate holder's legal name. The resulting Developer ID
  # signature still anchors its designated requirement to the stable team OU.
  # Refresh with `security find-identity -v -p codesigning` after cert renewal.
  nebelhaus.pounce.signingIdentity = "4D2693E75A214534ACE299861AE7FC3086573136";

  # Editor: Helix (hx) everywhere. $EDITOR/$VISUAL are hx by default; the "Nix
  # Config" palette/bar action opens ~/.config/nix in a new Helix terminal tab
  # (hearth.guiEditor now defaults to "hx"), and the file-association hijack
  # routes double-clicked json/md/ts/… to Helix too. No Cursor anywhere.
  nebelhaus.hearth.hijackFileAssociations = true;

  # ---- text expansion ----
  # The old Raycast "@@" snippet, now a rice option (nebelhaus.snippets → espanso
  # via the Espanso.app cask). Runs the SIGNED app bundle, not a nix-store binary,
  # so the one-time Accessibility grant survives reboots + nixpkgs bumps and the
  # espanso troubleshooting window stops popping up at login.
  nebelhaus.snippets = {
    enable = true;
    matches = [
      { trigger = "@@"; replace = "julienbmartel@gmail.com"; }
      { trigger = "##"; replace = "2044302465"; }
    ];
  };

  # ---- theme ----
  # The "orbits" Nebelung wallpaper (palette rings on a dark base).
  nebelhaus.theme.wallpaper = "orbits";

  # Obsidian stores its theme per vault. Keep the notes vault on the full
  # Nebelung theme and retire the old palette-only CSS snippet.
  nebelhaus.hearth.obsidianVaults = [
    "Library/Mobile Documents/iCloud~md~obsidian/Documents/notes"
  ];

  # ---- app roster ----
  # My personal launcher: which app owns which AeroSpace workspace + leader key.
  # This keyed map drives the tiling launcher, SketchyBar pills, and pounce
  # cheatsheet. Stable ids let pounce-generated package modules and this host
  # compose or override one app at a time.
  #
  # Most casks stay in homebrew.casks below, so cask = null avoids declaring
  # them twice. ChatGPT came from pounce Install App and owns its cask here;
  # Passwords is a system app, Things is App Store, and Trill ships via the rice.
  nebelhaus.apps = {
    ghostty = {
      order = 10;
      key = "t";
      name = "Ghostty";
      workspace = "T";
      appId = "com.mitchellh.ghostty";
      barIcon = ":ghostty:";
      label = "Ghostty (Terminal)";
      cask = null;
    };
    obsidian = {
      order = 20;
      key = "n";
      name = "Obsidian";
      workspace = "N";
      appId = "md.obsidian";
      barIcon = ":obsidian:";
      label = "Obsidian";
      cask = null;
    };
    things = {
      order = 30;
      key = "r";
      name = "Things3";
      workspace = "R";
      appId = "com.culturedcode.ThingsMac";
      barIcon = ":things:";
      label = "Things3";
      cask = null;
    };
    slack = {
      order = 40;
      key = "s";
      name = "Slack";
      workspace = "S";
      appId = "com.tinyspeck.slackmacgap";
      barIcon = ":slack:";
      label = "Slack";
      cask = null;
    };
    zen = {
      order = 50;
      key = "b";
      name = "Zen";
      workspace = "B";
      appId = "app.zen-browser.zen";
      barIcon = ":zen_browser:";
      label = "Zen (Browser)";
      cask = null;
    };
    trill = {
      order = 60;
      key = "m";
      name = "Trill";
      workspace = "M";
      appId = "com.nebelhaus.trill";
      barIcon = ":messages:";
      label = "Trill (Messages)";
      cask = null;
    };
    swather = {
      order = 70;
      key = "h";
      name = "Swather";
      workspace = "H";
      appId = "com.swather.app";
      # Swather has no app-font glyph — fa-hourglass (U+F254) in the Nerd Font.
      barIcon = builtins.fromJSON ''"\uf254"'';
      label = "Swather";
      cask = null;
    };
    claude = {
      order = 80;
      key = "c";
      name = "Claude";
      workspace = "C";
      appId = "com.anthropic.claudefordesktop";
      barIcon = ":claude:";
      label = "Claude";
      cask = null;
    };
    notion-calendar = {
      order = 90;
      key = "d";
      name = "Notion Calendar";
      workspace = "D";
      appId = "com.cron.electron";
      barIcon = ":calendar:";
      label = "Notion Calendar";
      cask = null;
    };
    passwords = {
      order = 100;
      key = "p";
      name = "Passwords";
      # Launcher-only: opens/focuses in the current workspace, no pill/auto-assign.
      label = "Passwords";
      cask = null;
    };
    chatgpt = {
      order = 110;
      key = "x";
      name = "ChatGPT";
      workspace = "X";
      appId = "com.openai.codex";
      barIcon = ":codex:";
      label = "ChatGPT";
      cask = "chatgpt";
    };
  };

  # Fully declarative Homebrew: a rebuild uninstalls (and zaps the data of) any
  # cask/brew not declared above. Every app I keep is now listed, so the only
  # thing this reaps is genuine cruft. Adding an undeclared app by hand and
  # forgetting to list it means it's gone on the next rebuild — that's the deal.
  nebelhaus.homebrew.cleanup = "zap";

  # Keep declared casks current on THIS machine (rice default stays off, so the
  # rest of the family keeps reproducible rebuilds). upgrade → a rebuild upgrades
  # outdated casks instead of pinning to whatever brew first installed; autoUpdate
  # → `brew update` first so it sees the newest versions. Together: date-released
  # family apps like trill self-update on every rebuild. Tradeoff I'm accepting
  # here: my rebuilds chase upstream latest and aren't perfectly reproducible.
  nebelhaus.homebrew.upgrade = true;
  nebelhaus.homebrew.autoUpdate = true;

  # My personal SketchyBar pills, switched on atop the rice default (core pills
  # stay on, the rest off): the agent-pane status paw (fed by the Claude hooks
  # wired below), the Elgato key light toggle, and the Harvest timer pill (reads
  # ~/.config/sketchybar/harvest_secrets.sh).
  nebelhaus.sill.items = {
    agents = true;
    elgato = true;
    harvest = true;
  };

  # Bar follows the display: top on the built-in (tucked under the notch),
  # bottom whenever an external is attached — i.e. bottom when docked to the
  # Studio Display, top on the go. Flips live on dock/undock via sill's
  # display_change hook; no rebuild needed to move it.
  nebelhaus.sill.position = "auto";

  # Claude Code's global memory (~/.claude/CLAUDE.md) — how I like to work across
  # every repo. Personal, so it lives here in the host; the rice just provides the
  # nebelhaus.claude.globalMd plumbing (hearth writes the file when set). Keep it
  # short and universal — repo-specific rules belong in each project's own CLAUDE.md.
  nebelhaus.claude.globalMd = ''
    # CLAUDE.md — global

    Personal defaults for how I (julienmartel) like to work, across every repo. Kept
    deliberately short and universal — repo-specific detail lives in each project's own
    CLAUDE.md, not here.

    ## How to answer me

    Load the `brief` skill at the start of every session and follow its shape for the
    whole session: verdict first, ≤5 anchored steps, and escalate to me only at ≥3/5
    (my usual bar) with a recommendation and a reversal cost. It governs code work,
    research, and anything I paste. Say "drop brief" / "full mode" to turn it off. The
    skill itself lives at `~/.claude/skills/brief/SKILL.md` (this host symlinks it out
    of `~/.config/nix/claude/skills/brief`); tune its tables there, no rebuild needed.

    ## Working in a git worktree

    My super+c (`⌘C`) zellij hotkey spawns Claude panes as `claude --worktree`:
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
      default mode, to build without asking.** A build (`bench try`, `nix build`,
      a project's own run/verify skill) is read-only toward every checkout and
      never activates anything, so it's exactly what a worktree is for — don't
      stop at "the diff is ready" when you could have built it. This holds even
      when the build compiles a **child** repo from a parent dir's worktree
      session (e.g. a workshop worktree building the nebelhaus family, or any
      `bench try` that pulls in a sibling repo): the child's checkout is only
      read, not mutated, so go ahead. Only *activation* (`bench try switch`,
      `darwin-rebuild switch`) stays off-limits from a worktree — activating
      changes this machine's running state, which is a main-checkout job.
    - **Pushing already-committed work is fine from a worktree.** You have my
      standing permission, in default mode, to run a repo's push/ship step (e.g.
      `bench ship`) from a worktree without asking — it only pushes commits that
      already exist and never activates anything. (`bench ship` specifically
      operates on the *main* checkouts, so it ripples merged/released work
      downstream; it does not push your unmerged `worktree-*` branch.)
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
      "PR open." Shipping isn't merging: `bench ship` pushes committed state and
      bumps locks, it never folds your branch into main.
    - **When I say ship/land/merge, `/ship` finishes the whole job** (see the
      ship skill): merge the PR, then clean up every worktree *this session*
      spun up — a session often hand-creates a sibling-repo worktree for
      out-of-repo work, and those aren't auto-reaped, so merge their PRs too and
      `git worktree remove` them. When it's all landed and nothing ≥3/5 needs my
      attention (don't wait on CI unless that's the point), `/ship` reports and
      stops. It does **not** close this pane or open a new one — I open and close
      my own panes (see "Don't drive my multiplexer" below). The current worktree
      isn't reaped here (you're still in it); it's cleaned up when I close the
      pane myself (the `wt` remove hook) or by a later `wt reap`.
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
    infra: nebelhaus family, qnap-mediastack, ~/.config/nix, and the like). In shared or
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
    nebelhaus family (`nebelung`, `pounce`, `nebelhaus`, …) sits under the
    `nebelhaus` workshop dir, whose `.gitignore` lists each child. **That
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

  # A system CLI not in den's baseline.
  environment.systemPackages = [ pkgs.biome ];

  # ---- personal apps (den ships ghostty; prowl aerospace; sill sketchybar) ----
  homebrew.taps = [ "pear-devs/pear" ];
  homebrew.brews = [
    "ical-buddy"
    "gogcli"
    "mas" # the CLI only — masApps is intentionally unused (it hangs)
  ];
  homebrew.casks = [
    "cap"
    "claude"
    "elgato-control-center"
    "font-hack-nerd-font"
    "font-jetbrains-mono-nerd-font"
    "framer"
    "gcloud-cli"
    "google-chrome"
    "insomnia"
    "legcord"
    "loom"
    "notion-calendar"
    "obsidian"
    "pear-devs/pear/pear-desktop"
    "protonvpn"
    "qfinder-pro"
    "slack"
    "tailscale-app"
    "zen"
  ];
  # App Store-only (no cask). mas can't sign in or first-acquire apps on modern
  # macOS (Apple removed the API); it only reinstalls/upgrades apps already bought
  # via the App Store GUI — so acquire these by hand once:
  #   Things (904280696) · Xcode (497799835)
  # System Settings → App Store → automatic updates keeps them current thereafter.

  # ---- personal home layer: extra packages, private git config, secrets ----
  home-manager.users.${username} =
    { config, lib, pkgs, nebelung, ... }:
    {
      home.packages = with pkgs; [
        # Claude Code, minus two annoyances it has no settings for:
        #
        # 1. The permission-mode footer line ("⏵⏵ auto mode on (shift+tab to
        #    cycle)") under the custom statusline — with 4 panes per tab those
        #    rows add up. declutter-claude-footer.py patches the JS source
        #    embedded in the bun-compiled binary so the line renders as null;
        #    its regexes pin code structure, not minified names, and FAIL THE
        #    BUILD (match count ≠ 2) if a claude-code update reshapes the
        #    footer — so a bump can break here; see the script header for how
        #    to re-derive. autoSignDarwinBinariesHook re-signs the patched
        #    Mach-O during fixup (unsigned = SIGKILL on Apple Silicon), and
        #    the package's own versionCheckPhase proves the result still runs.
        #
        # 2. The hard-coded sleep blocker: on macOS the agent silently spawns
        #    `caffeinate -i -t 300` (renewed while it works). Shadow
        #    caffeinate with a no-op on claude's PATH only — everything else,
        #    including pounce's caffeinate command, still gets the real
        #    /usr/bin/caffeinate. Sleep stays manual.
        (
          let
            claude-code-defootered = claude-code.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                python3
                darwin.autoSignDarwinBinariesHook # re-sign the patched Mach-O in fixup
              ];
              postInstall = (old.postInstall or "") + ''
                python3 ${./declutter-claude-footer.py} "$out/bin/.claude-wrapped"
              '';
            });
          in
          symlinkJoin {
            name = "claude-code-no-caffeinate";
            paths = [ claude-code-defootered ];
            nativeBuildInputs = [ makeBinaryWrapper ];
            postBuild = ''
              rm "$out/bin/claude"
              makeBinaryWrapper "${claude-code-defootered}/bin/claude" "$out/bin/claude" \
                --inherit-argv0 \
                --prefix PATH : "${writeShellScriptBin "caffeinate" "exit 0"}/bin"
            '';
          }
        )
        gemini-cli-bin
        orbstack

        # The workshop CLI (~/code/nebelhaus): status / try / ship / rebuild
        # for the whole rice family. A real command on PATH (not an alias) so
        # it works from scripts, other shells, and non-interactive contexts;
        # `bench try switch` supersedes rebuild-pounce (it overrides ALL the
        # local checkouts, not just pounce).
        (writeShellScriptBin "bench" ''exec "$HOME/code/nebelhaus/bench" "$@"'')
      ];

      # Dev loop for hacking on pounce: rebuild the system against the LOCAL
      # pounce checkout (picks up uncommitted edits) instead of the pinned
      # github input. Normal `darwin-rebuild` still uses github → reproducible.
      # When happy: commit + push pounce, then a plain rebuild pins the new rev.
      programs.zsh.shellAliases.rebuild-pounce = ''
        (cd "$HOME/.config/nix" \
          && nix build .#darwinConfigurations.mbp.system \
               --override-input nebelhaus/pounce "path:$HOME/code/nebelhaus/pounce" \
          && sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp)
      '';

      # Text expansion moved up to nebelhaus.snippets (darwin level) — the rice
      # option now owns espanso, via the signed Espanso.app cask.

      programs.git.settings = {
        http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
        core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      };

      # Claude Code — my personal "brief" answer-shape skill: verdict first, ≤5
      # anchored steps, escalate only at ≥3/5 with a recommendation + reversal cost.
      # The stanza in nebelhaus.claude.globalMd above is what makes it load every
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

      home.file."Library/Application Support/Zen/distribution/policies.json".text = builtins.toJSON {
        policies = {
          ExtensionSettings = {
            "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
              installation_mode = "force_installed";
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
            };
          };
        };
      };

      home.activation.stylusNebelung =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -d "$HOME/Library/Application Support/Zen" ]; then
             echo "→ Stylus (Zen): to apply the nebelung palette to your userstyles, import the generated JSON:"
             echo "    ${nebelung.themes}/stylus/nebelung-stylus.json"
          fi
        '';

      # Claude Code — reinstate our hooks in settings.json on every rebuild.
      #  • WorktreeCreate/WorktreeRemove: Super-c / `⌘C` (rice: hearth/zellij)
      #    spawns `claude --worktree`; these hand the create/remove off to `wt`
      #    so worktrees land under ~/.cache/claude-worktrees instead of inside the
      #    repo — and so closing a pane never loses uncommitted work (wt parks it
      #    on the branch first) and stays resumable (`wt` to list, `wt <name>` to
      #    reopen). `wt` itself ships in the rice (nebelhaus/modules/den); we just
      #    point the hooks at its system path here (Claude owns settings.json, so
      #    hook wiring is the host's job — same as the sketchybar hooks below).
      #  • UserPromptSubmit/Notification/Stop/SessionEnd: feed the `agents` bar
      #    paw (nebelhaus.sill.plugins) — each fires agents-hook.sh from inside the
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
          wtbin="$1"
          hook="$2"
          mkdir -p "''${settings%/*}"
          tmp="$settings.hm-seed"
          if [ -s "$settings" ]; then base="$settings"; else base="$tmp.base"; printf "{}" > "$base"; fi
          ${pkgs.jq}/bin/jq \
            ".hooks.WorktreeCreate = [{hooks:[{type:\"command\",command:\"''${wtbin} create\"}]}]
             | .hooks.WorktreeRemove = [{hooks:[{type:\"command\",command:\"''${wtbin} remove\"}]}]
             | .hooks.UserPromptSubmit = [{hooks:[{type:\"command\",command:\"''${hook} working\"}]}]
             | .hooks.Notification = [{hooks:[{type:\"command\",command:\"''${hook} waiting\"}]}]
             | .hooks.Stop = [{hooks:[{type:\"command\",command:\"''${hook} idle\"}]}]
             | .hooks.SessionEnd = [{hooks:[{type:\"command\",command:\"''${hook} remove\"}]}]" \
            "$base" > "$tmp"
          mv "$tmp" "$settings"
          rm -f "$tmp.base"
        ' "$HOME/.claude/settings.json" "/run/current-system/sw/bin/wt" "$HOME/.config/sketchybar/plugins/agents-hook.sh"
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
                \"Bash(haus:*)\"
             ] | unique)" \
            "$base" > "$tmp"
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
