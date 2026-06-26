#!/bin/bash
set -euo pipefail

# Only run in remote (web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install Nix if not already present
if ! command -v nix &>/dev/null; then
  echo "Installing Nix via DeterminateSystems installer..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux \
      --no-confirm \
      --init none
fi

# Source Nix into the current shell environment
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Persist PATH for the session so subsequent Claude tool calls can find nix
echo "export PATH=\"/nix/var/nix/profiles/default/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

echo "Nix $(nix --version) ready."
