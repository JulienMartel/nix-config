# tracker — the to-do list as one Go binary: a CLI for agents and scripts, a
# fullscreen TUI for a person. The notes it reads live in the Obsidian vault;
# this only builds the tool. `hosts/mbp/apps.nix` puts it on PATH.
{ lib, buildGoModule }:

buildGoModule {
  pname = "tracker";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ./.;
    # `result*` is what `nix build -o` leaves beside the module; the plugin dir
    # and the base file are embedded and must stay.
    filter = path: _: builtins.baseNameOf path != "result" && !(lib.hasPrefix "result-" (builtins.baseNameOf path));
  };

  subPackages = [ "cmd/tracker" ];

  # The first `nix build` after a go.mod change prints the right hash.
  vendorHash = "sha256-+8gXQC5v66mszMckm67hiOQHk1NjHa3wa1QoKE9sGoY=";

  # The TUI answers `--version`; nothing else needs ldflags.
  ldflags = [ "-s" "-w" "-X main.version=0.1.0" ];

  meta = {
    description = "A to-do list kept as markdown notes in an Obsidian vault: CLI and TUI";
    mainProgram = "tracker";
    platforms = lib.platforms.unix;
  };
}
