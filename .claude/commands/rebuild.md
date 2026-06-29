---
description: Build and switch this nix-darwin config; diagnose the error if the build fails
argument-hint: "[build]  (pass 'build' to build only, skipping the switch)"
allowed-tools: Bash(nix build:*), Bash(darwin-rebuild switch:*), Bash(sudo darwin-rebuild switch:*), Bash(nix flake check:*), Read
---

Rebuild the nix-darwin configuration for host `mbp` from this repo (`~/.config/nix`).

Arguments: `$ARGUMENTS`
- If the argument is `build`, do the build step only and STOP before switching (a dry check).
- Otherwise, build and then switch.

Steps:

1. **Build:** run `nix build .#darwinConfigurations.mbp.system`.
   - If it **fails**: do NOT switch. Nix errors are verbose — read the output from the *bottom up* to find the real cause (the actual error is usually the last `error:` line, not the stack trace above it). Then explain in 2-3 plain sentences: what broke, which file/option is responsible, and the concrete fix. If the fix is obvious and small (a typo, a wrong option name, a missing `enable`), offer to apply it. Stop here.
   - If it **succeeds**: continue.

2. **Switch** (skip if the argument was `build`): run `sudo ./result/sw/bin/darwin-rebuild switch --flake .#mbp`.
   - On success, report it succeeded in one line and mention anything notable that changed (new generation, packages added/removed) if visible in the output.
   - On failure, surface the activation error plainly (activation failures are usually a launchd agent, a file collision, or a Homebrew step — say which).

Keep the final report tight: a human wants to know "did it work, and if not, what's the one thing to fix." Don't paste the full nix log unless asked.
