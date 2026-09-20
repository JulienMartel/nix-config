{
  description = "julienmartel's machine — a haus desktop";

  # The whole desktop (system + shell + pounce + nebelung) comes from the public
  # haus flake. This private config holds only what's personal: the host.
  # Update everything with:  haus update
  inputs.haus.url = "github:hausfold/haus";

  outputs =
    { self, haus, ... }:
    {
      darwinConfigurations.mbp = haus.mkHaus {
        username = "julienmartel";
        hostname = "mbp";
        host = ./hosts/mbp;
      };

      # `nix build ~/.config/nix#tracker` → result/bin/tracker, the to-do CLI in
      # pkgs/tracker — built from the machine's own pkgs, so it is the very
      # derivation hosts/mbp/apps.nix puts on PATH.
      packages.aarch64-darwin.tracker = self.darwinConfigurations.mbp.pkgs.callPackage ./pkgs/tracker { };
    };
}
