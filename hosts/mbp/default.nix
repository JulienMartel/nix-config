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
  nebelhaus.pounce.signingIdentity = "DE2FB6DF7E66864C5F254DACF0AFC1B00685BA5D";

  # The Super-Shift-t "new tab" picker opens on just these instead of all of $HOME.
  nebelhaus.hearth.newTabDirs = [
    "m"
    "code"
    ".config"
  ];

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
    "cursor"
    "elgato-control-center"
    "figma"
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
  # App Store-only (no cask; mas can't reliably install on modern macOS):
  #   Dropover (1355679052) · Things (904280696) · Xcode (497799835)
  # Install by hand; System Settings → App Store → automatic updates keeps them current.

  # ---- personal home layer: extra packages, private git config, secrets ----
  home-manager.users.${username} =
    { config, lib, pkgs, nebelung, ... }:
    {
      home.packages = with pkgs; [
        claude-code
        opencode
        gemini-cli-bin
        orbstack
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

      # Text expansion (the old Raycast "@@" snippet, nix-style). Needs a
      # one-time Accessibility grant in System Settings; a nixpkgs bump that
      # changes espanso's store path may require re-granting.
      services.espanso = {
        enable = true;
        configs.default.show_icon = false; # no menu bar icon
        matches.default.matches = [
          { trigger = "@@"; replace = "julienbmartel@gmail.com"; }
          { trigger = "##"; replace = "2044302465"; }
        ];
      };

      programs.git.extraConfig = {
        http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
        core.attributesfile = "${config.home.homeDirectory}/.gitattributes_global";
      };

      # Obsidian: paint the vault with Nebelung. The theme is a nebelung *port*
      # (a CSS snippet overriding Obsidian's --color-* vars); we DON'T use the
      # Catppuccin community theme — it re-introduces the blue Nebelung strips
      # out, and a snippet can't reliably override a full theme's own rules.
      # So: Default theme + this snippet.
      #
      # The vault lives in iCloud, so we COPY the snippet (a store symlink would
      # sync as a dangling link to other devices) rather than link it. Obsidian
      # owns appearance.json (rewrites it on any settings change), so we don't
      # freeze it — jq patches it in place, idempotently, each rebuild:
      # Default theme, dark mode, snippet enabled. Everything stays writable.
      #
      # Requires the obsidian port to be present in the pinned nebelung input;
      # until `nix flake update nebelung` (in nebelhaus) propagates it, the
      # `-f` guard makes this a no-op instead of a failed rebuild.
      home.activation.obsidianNebelung =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          vault="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes/.obsidian"
          snippet="${nebelung.themes}/obsidian/nebelung.css"
          if [ -d "$vault" ] && [ -f "$snippet" ]; then
            run mkdir -p "$vault/snippets"
            run install -m 0644 "$snippet" "$vault/snippets/nebelung.css"
            app="$vault/appearance.json"
            [ -f "$app" ] || echo '{}' > "$app"
            tmp="$(mktemp)"
            ${pkgs.jq}/bin/jq \
              '.cssTheme = "" | .theme = "obsidian"
               | .enabledCssSnippets = ((.enabledCssSnippets // []) + ["nebelung"] | unique)' \
              "$app" > "$tmp" && run mv "$tmp" "$app"
          fi
        '';

      # Secrets + tooling that shouldn't live in the public rice.
      programs.zsh.initContent = lib.mkAfter ''
        export GEMINI_API_KEY="$(cat ~/.secrets/google-api-key)"
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    };
}
