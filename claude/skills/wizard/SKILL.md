---
name: wizard
description: >-
  Turn the human half of a setup into a resumable script I run myself — the keys you can't
  mint, the dashboards you can't click, the ordered steps that must happen in order. Use
  when I say /wizard, "walk me through it", "what do you need from me", "set this up",
  "I'll do my part", or whenever finishing a task needs three or more actions only I can
  take. You write the script. You never run it.
---

# Wizard — the steps only I can do, as a script instead of a chat message

Instructions in a chat scroll away. I lose my place, paste the wrong key, and come back
tomorrow with no idea which step I finished. A wizard is the same instructions as a
**resumable script with state**: it knows what's already done, it opens the dashboard for
me, it takes the secret without echoing it, and re-running is free.

**You write it. I run it.** That is the whole design, and it buys three things: the keys
never enter your context, the screen is never taken from me, and I can stop halfway.

## When this instead of a "Need from you" block

| | |
|---|---|
| **1–2 human steps** | `/brief`'s **Need from you** block. A wizard is overkill |
| **3+ steps, or any ordering, gating or credential** | this skill |
| **Anything irreversible** (a DNS cutover, a migration, a rotation) | this skill, with a confirm gate on the irreversible one |

## 1. Scope it, and show me before you write a line

Read the repo first, don't ask me what it needs. Look at `secretspec.toml`, `.env*`,
`*.example`, CI workflow `secrets.` / `vars.` references, `flake.nix`, `wrangler.toml`,
docker configs, and any `README` install section. For each thing that's missing, decide
**where the value lands**:

| Lands in | When |
|---|---|
| **the login keychain**, via `secretspec set NAME` | any secret in a repo of mine. This is the house mechanism — `secretspec.toml` declares NAMES, the keychain holds values, `secretspec run -- cmd` injects them. **Never write a secret to `.env`** unless the repo already has one and no `secretspec.toml` |
| `gh secret set` / `gh variable set` | CI needs it |
| **nowhere** | a pure action: click a toggle, grant a permission, approve an invite, boot a VM |

Then print the stage list and stop. One line each: what it does, where the value lands,
and whether it's reversible. **I confirm before you write the script** — this is the only
gate, and it's cheap.

## 2. Write it

Location decides itself:

- **Repeatable, or someone else will need it** → `scripts/setup-<thing>` in the repo,
  committed, linked from the README. That's a real deliverable.
- **One-off** → the session scratchpad. Say the path, don't commit it.

Rules the template exists to enforce:

- **Idempotent.** A value already set shows as the default; ↵ keeps it. Re-running after a
  failure re-does nothing that worked.
- **No back button.** Stages run forward. Ctrl-C and re-run is the correction mechanism,
  and it must be cheap enough that this is fine.
- **Secrets never echo** and never reach a log, a temp file, or your context.
- **Every URL opens itself.** I should never have to find a dashboard by hand.
- **State on screen.** `[3/7]` and the stage name, always.
- **Nothing destructive without a typed confirmation.**

### Template

```bash
#!/usr/bin/env bash
set -euo pipefail
TOTAL=7; STEP=0
b=$'\033[1m'; d=$'\033[2m'; g=$'\033[32m'; r=$'\033[0m'

stage() { STEP=$((STEP+1)); printf '\n%s[%d/%d] %s%s\n' "$b" "$STEP" "$TOTAL" "$1" "$r"; }
note()  { printf '%s      %s%s\n' "$d" "$1" "$r"; }
ok()    { printf '%s      ✓ %s%s\n' "$g" "$1" "$r"; }
visit() { note "opening $1"; open "$1" 2>/dev/null || note "open this: $1"; }
pause() { read -r -p "      press ↵ when done (Ctrl-C to stop) "; }
confirm(){ read -r -p "      type $1 to continue: " a; [ "$a" = "$1" ] || { echo "      stopped."; exit 1; }; }

# a secret: keychain-backed, never echoed, ↵ keeps what's there
secret() { # secret NAME "human description"
  if secretspec get "$1" >/dev/null 2>&1; then ok "$1 already set"; return; fi
  note "$2"; read -rs -p "      $1: " v; echo
  [ -n "$v" ] || { echo "      empty, stopping."; exit 1; }
  printf '%s' "$v" | secretspec set "$1" >/dev/null; ok "$1 stored in the keychain"
}

# a choice: the native picker if pounce is here, a numbered prompt if not
choose() { # choose "prompt" opt1 opt2 ...
  local p="$1"; shift
  if command -v pounce >/dev/null; then printf '%s\n' "$@" | pounce -p "$p"
  else select c in "$@"; do [ -n "$c" ] && { echo "$c"; return; }; done; fi
}

printf '%s\n%s\n' "${b}<what this sets up>${r}" "${d}Ctrl-C any time. Re-running is safe and skips what's done.${r}"

# ---- stages ----------------------------------------------------------------

stage "Create the API token"
visit "https://example.com/settings/tokens"
note "scopes: read:foo, write:bar"
secret EXAMPLE_TOKEN "paste the token (it won't echo)"

stage "Flip the dashboard toggle"
visit "https://example.com/project/settings#webhooks"
note "turn ON 'Send delivery events'"
pause; ok "webhooks on"

stage "Point DNS at the worker"
note "⚠️  this is the irreversible one — the old record stops resolving"
confirm "CUTOVER"
# …

printf '\n%s✓ done.%s  next: %s\n' "$g" "$r" "<the command I run now>"
```

Above the stages the template is identical every time. Only the stages change — a
consistent wizard is one I stop reading and just follow.

## 3. Hand it over

Report in the `/brief` shape: one line on what it sets up, then the command to run:

```
bash scripts/setup-foo          # ~4 min, 3 of the 7 steps need a browser
```

Say **how long** and **what I'll need in front of me** (a login, a phone, a credit card).
Then stop and wait — don't run it, don't poll for it, don't "verify" it by inspecting the
keychain. When I say it's done, pick the work back up.

If a step turns out to be mine and it isn't happening today, offer once:
`things add "<the step>"` — one line, and drop it if I don't bite.
