#!/usr/bin/env bash
# .agents/setup.sh — the one session bootstrap, for every harness.
#
# Cloud agent sessions (Claude Code on the web, Codex cloud, an OpenCode
# container, CI) boot a bare Linux box with no Nix. This repo IS a flake — it is
# barely anything else — so without Nix a session can't regenerate flake.lock or
# evaluate the host at all. This installs Determinate Nix once, puts it on PATH
# for the rest of the session, and points Nix at the agent proxy's CA.
#
# It can't SWITCH from a container either way: darwin-rebuild is macOS-only, and
# activation is always the machine's own job, at its keyboard.
#
# Wired up as:
#   Claude Code  .claude/settings.json  → SessionStart hook
#   Codex        .codex/hooks.json      → SessionStart hook
#   OpenCode     .opencode/plugins/nix-bootstrap.js
#   anything else — run it yourself: ./.agents/setup.sh   (idempotent, safe)
set -euo pipefail

# A real workstation is macOS, where the rice already installed Determinate Nix.
# Nothing to do — and nothing here would be welcome there.
if [ "$(uname -s)" = "Darwin" ]; then
  exit 0
fi

nix_bin="/nix/var/nix/profiles/default/bin"

# Install Nix if it isn't here yet. Idempotent: containers are usually cached
# after the first run, so re-runs (resume / clear / compact) skip straight
# through. Determinate's installer matches the rice ("Determinate owns the nix
# daemon"); --init none is the container-safe, daemonless mode.
if ! command -v nix >/dev/null 2>&1 && [ ! -x "$nix_bin/nix" ]; then
  echo "Installing Nix via the Determinate Systems installer..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux \
      --no-confirm \
      --init none
fi

# Source Nix into this shell.
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Persist an env line everywhere this harness might read it back. Claude Code
# hands a hook $CLAUDE_ENV_FILE; Codex cloud and plain containers carry env
# through the shell rc instead. Appending only when absent keeps re-runs clean.
persist_env() {
  local line="$1" f
  for f in "${CLAUDE_ENV_FILE:-}" "$HOME/.bashrc" "$HOME/.profile"; do
    [ -n "$f" ] || continue
    [ -e "$f" ] || [ "$f" = "${CLAUDE_ENV_FILE:-}" ] || continue
    grep -qF "$line" "$f" 2>/dev/null || echo "$line" >>"$f"
  done
}

persist_env "export PATH=\"$nix_bin:\$PATH\""

# Nix's own fetcher (flake inputs from GitHub, cache.nixos.org) tunnels through
# the agent proxy, which re-terminates TLS — point Nix at the proxy CA or every
# fetch fails verification. The path differs per harness; take the first that
# exists, and let an already-set NIX_SSL_CERT_FILE win.
for ca in "${NIX_SSL_CERT_FILE:-}" /root/.ccr/ca-bundle.crt \
  /etc/ssl/certs/ca-certificates.crt; do
  if [ -n "$ca" ] && [ -f "$ca" ]; then
    persist_env "export NIX_SSL_CERT_FILE=$ca"
    break
  fi
done

echo "Nix $(PATH="$nix_bin:$PATH" nix --version 2>/dev/null || echo '(installed, not yet on PATH)') ready."
