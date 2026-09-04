{ username, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      claude-code =
        let
          # `prev`, never `final`: `final` here is infinite recursion.
          patchedCC = prev.claude-code.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              prev.python3
              prev.darwin.autoSignDarwinBinariesHook
            ];
            # The liveness pass runs last: it reads the offsets the other two
            # recorded, and drops the bytecode cache that would shadow them.
            postInstall = (old.postInstall or "") + ''
              edits="$NIX_BUILD_TOP/claude-tui-edits.jsonl"
              python3 ${./declutter-claude-footer.py} "$out/bin/.claude-wrapped" "$edits"
              python3 ${./statusline-permission-mode.py} "$out/bin/.claude-wrapped" "$edits"
              python3 ${./claude-bytecode-liveness.py} "$out/bin/.claude-wrapped" "$edits"
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
          inherit (prev.claude-code) meta version;
        };
    })
  ];

  haus.ai.autoMode.environment = [
    "### Org-wide"
    "**Organization**: hausfold, a one-person org. github.com/hausfold/* (haus, pounce, nebelung, scruff, trill, perch, snug, factory, holt, ops, meridian, workshop, hausfold.co, homebrew-tap) and github.com/julienmartel/* are all owned solo by the user, who is the only committer and the only reviewer. Every checkout under ~/code/workshop, ~/code and ~/.config/nix is theirs."
    "**Cloud provider(s)**: None. GitHub Actions is the only CI; Cloudflare holds the hausfold.co DNS and the tunnels under hooks.hausfold.co."
    "**Repository visibility**: hausfold/* and julienmartel/* are PUBLIC open-source repos the user publishes on purpose — a commit, push or PR there is ordinary work, not publication of something private. jwhatty/joshua-whatman is a CLIENT site (public): prepare changes there and ask before pushing."
    "**Internal sharing / snippet hosting**: None — public gists and paste services are outside the boundary."
    "**Secrets management**: secretspec with the macOS login keychain. secretspec.toml declares NAMES (GITHUB_TOKEN, GITHUB_WEBHOOK_SECRET, ANTHROPIC_API_KEY); values live in Keychain and `secretspec run -- cmd` injects them into one process. A value is never printed, echoed, committed or written to a file."
    "**Default / protected branches**: `main` everywhere. Work lands through a PR from a `worktree-<lane>` branch, squash-merged with `gh pr merge --squash --delete-branch`. `worktree-*` branches are single-agent and nobody bases on them, so rebasing and force-pushing one is free."
    "**CI/CD deploy targets**: hausfold.co deploys from its `main` via GitHub Actions; `bench release` stamps a release into hausfold/homebrew-tap. Releases and publishes happen only on the user's explicit ask."
    "**Network posture**: open internet. The user's own hosts are this Mac, its tart guests on 192.168.64.0/24, and a QNAP NAS on the LAN."
    "**Host containment**: This Mac is the user's personal single-user workstation. It runs several parallel agent lanes at once — scruff worktrees under ~/.cache/scruff/<repo>/<lane> and ~/.cache/claude-worktrees — and a lane may boot its own disposable headless macOS VM with `tart` (`scruff runtime up <lane> --backend tart`). A guest is cloned from a golden image, lives at 192.168.64.x as user `admin`, renders nothing on the user's screen, and is thrown away when the lane is done."
    "**Source control**: github.com/hausfold/* and github.com/julienmartel/* (trusted, solo-owned); jwhatty/joshua-whatman (client)."
    "**Trusted internal domains**: github.com, hausfold.co, hooks.hausfold.co, localhost, and the tart guest subnet 192.168.64.0/24."
    "**Trusted cloud buckets**: None."
    "**Key internal services**: the hausfold tools running on this Mac — trill (notifications), Pounce (the command palette), Perch (the notch shelf), meridian (an agent under co.hausfold.meridian), sketchybar, aerospace, scruff, holt. Their launchd agents (co.hausfold.*, org.nixos.*), plists, caches and SQLite databases under ~/Library/Application Support and ~/.config are the user's own development targets: inspecting, editing, reloading and restarting them is ordinary work on those tools."
    "**Internal package registry**: nixpkgs through the flake lock; Homebrew through hausfold/homebrew-tap."
    "**Sensitive data locations & audiences**: the macOS keychain, ~/.ssh, secretspec values, ~/.claude/.credentials.json, OAuth tokens under ~/Library/Preferences and ~/Library/Application Support — read only into the process that needs them, never printed, committed or sent anywhere but their own provider. Mail and calendar data reached through the Gmail and Google Calendar connectors stays in the conversation."
    "**Data retention / declassification**: None configured."
    "**Sensitive remote targets**: any host or namespace whose name carries `prod` or `production`; the live hausfold.co deploy; the QNAP NAS's data volumes."
    "**Protected deployment namespaces / environments**: hausfold/homebrew-tap (a release surface) and the hausfold.co deploy — only on the user's explicit ask."
    "**Protected IaC scopes**: activating THIS machine (`haus rebuild`, `darwin-rebuild switch`, `bench try switch`) is gated by a separate PreToolUse hook, agent-desktop-guard, which re-opens the permission prompt itself. It is not a production apply."
    "### User-specific"
    "**Primary use of Claude Code**: building and maintaining the hausfold desktop layer (Nix, shell, Swift, Go) across many small solo-owned repos at once, plus occasional client web work."
    "**Trusted repo**: every repo under ~/code/workshop, ~/code, ~/.config/nix, ~/.cache/scruff and ~/.cache/claude-worktrees. One session routinely edits, commits and pushes in several of them — a `scruff child` worktree of a sibling repo is the normal cross-repo flow — so moving between them is not scope escalation."
    "**Org-specific CLIs**: haus, bench, scruff, wt, holt, trill, perch, pounce, tart, secretspec, gh, nix, darwin-rebuild — all the user's own infrastructure."
  ];

  haus.ai.autoMode.allow = [
    "Workshop Scope: every checkout under ~/code/workshop, ~/code, ~/.config/nix, ~/.cache/scruff and ~/.cache/claude-worktrees is a repo the user owns solo, and one session routinely works across several of them. Reading, editing, committing, rebasing, force-pushing its own `worktree-*` branch, `git reset --hard origin/main` inside a lane, `git worktree` operations, opening a PR, and pushing to any of them are ordinary work — not scope escalation, Git Destructive, Out-of-Place Publication or Create Public Surface (the repos are public on purpose). A force-push to `main` and deleting a remote branch whose PR is still open are still judged normally. One checkout under these paths is NOT the user's and this rule does not reach it: jwhatty/joshua-whatman, wherever it sits and including its lanes under ~/.cache/scruff/joshua-whatman. Editing and committing there is ordinary; pushing, opening a PR and merging are judged as they would be on any repo the user does not own."
    "PR Merges the User Asked For: `gh pr merge` (squash, --delete-branch) on hausfold/* or julienmartel/* when the user said ship, merge, /ship or 'merge and clean up' in this session, or a standing instruction in CLAUDE.md/AGENTS.md covers it (the factory's reviewed filter). The user is the only reviewer of these repos, so this is not Merge Without Review, Self-Approval or CI Bypass. `--admin` and merging over a red check are still judged normally."
    "Lane VMs: `tart` in every verb (clone, run --no-graphics, ip, list, stop, delete, exec, set, get, pull, push to the local golden image) and anything sent over ssh, scp or rsync to a tart guest — 192.168.64.0/24, a `$(tart ip …)`, user `admin` — is work on a disposable headless macOS the lane created from a golden image. sudo, TCC.db edits, killall, launchctl, reboots, rebuilds, `rm -rf` and deleting the VM itself are all fine there: the guest is never production, never shared, and never on the user's screen. Not Remote Shell Writes, Sensitive Remote Exec, Production Reads, Interfere With Workloads, Irreversible Local Destruction, Security Weaken or Node Lifecycle Operations. What the guest is disposable for is the machine, never the secret: copying a credential onto one — an ssh key, a keychain value, a secretspec value, ~/.claude/.credentials.json — is judged exactly as copying it anywhere else."
    "This Mac's Own Desktop and Tools: on the host, restarting, reloading, inspecting or editing the user's own desktop and hausfold services — `killall Dock|Finder|sketchybar`, `launchctl kickstart|bootout|bootstrap|list` of co.hausfold.* / org.nixos.* agents, `sketchybar --reload`, `aerospace …`, `open`, `osascript`, `screencapture`, `pkill` of a hausfold process, `haus rebuild|rollback|update|doctor`, `darwin-rebuild switch`, `bench try switch`, their launchd plists, and the caches and SQLite databases under ~/Library/Application Support/{Trill,Perch,Pounce,scruff,meridian} and ~/.config — is ordinary development of those tools. Whether a call would touch what is on the user's screen is decided by a separate PreToolUse hook (agent-desktop-guard) that re-opens the prompt itself; do not gate it a second time here. Not Interfere With Workloads, Unauthorized Persistence, Production Deploy, Blind Apply or Protected-Scope IaC Apply."
    "Agent Config Is Project Scope: the user's own agent configuration — ~/.claude (skills, plugins, statusline, the hooks haus writes), ~/.agents, ~/.codex, ~/.pi, ~/.config/opencode, the `haus.ai.*` options in ~/.config/nix, and each repo's AGENTS.md/CLAUDE.md — is source the user has agents maintain (haus generates most of it on rebuild). Reading and editing it is ordinary work, not Self-Modification or Instruction Poisoning. The one carve-out stays judged as Self-Modification: a change that widens the agent's own permissions or disarms a safety check — permissions.allow, permissions.defaultMode, autoMode.*, setting HAUS_DESKTOP_OK, removing or rerouting a PreToolUse hook, or dropping a Notification, Stop, UserPromptSubmit or PostToolUse entry, which is how a lane tells the user it is waiting on them."
    "Nix and Homebrew Toolchain: `nix build|eval|run|develop|shell|flake`, `nix run nixpkgs#<tool>`, `nix-store`, `darwin-rebuild build`, `nixfmt`, `brew` against the user's tap, `bench`, `haus`, `holt`, `secretspec check|run`, and running a repo's test suite (`bats`, `swift test`, `go test`, `cargo test`, `npm test`) are the standard build tools here and read-only toward every checkout. Not Code from External, Untrusted Code Integration or Package Registry Bypass."
    "Own-Machine Reads: reading the user's own app state on this Mac — transcripts under ~/.claude/projects, ~/.pi/agent/sessions, `launchctl list|print`, `log show`, `defaults read`, `tart list`, the hausfold tools' SQLite databases, Nix and Homebrew profiles, and `security find-generic-password -s <name>` for a secretspec-declared NAME piped straight into the process that needs it — is Read-Only / Standard Credentials, not Credential Exploration, Exfil Scouting or PII Data Handling. Printing a secret VALUE into the transcript, `security dump-keychain`, and copying a credential to a file stay blocked."
    "Deleting What the Lane Made: `rm -rf` of a lane's own scratchpad, its build outputs (`result`, `.build`, `node_modules`, `target`, `dist`), a tart VM the lane cloned, `git worktree remove` / `scruff reap` of a merged lane, and `scruff park|unpark` are session housekeeping, not Irreversible Local Destruction, Unverifiable Deletion Target or Shared Scratch Sweep. Deleting a main checkout under ~/code/workshop, or anything under ~/Documents, ~/Downloads or ~/Pictures, stays judged normally."
  ];

  home-manager.users.${username} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Merged, never written whole, and the allowlist UNIONed: Claude rewrites
      # this file itself, so a plain write drops what it and `/config` put there.
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
          patchWith = args: ''
            run ${pkgs.python3}/bin/python3 ${./json-patch.py} ${args}
          '';
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          patchWith "merge ${settings} ${lib.escapeShellArg (builtins.toJSON patch)}"
          + patchWith "union ${settings} permissions.allow ${lib.escapeShellArg (builtins.toJSON allow)}"
        );
    };
}
