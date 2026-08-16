{
  description = "julienmartel's machine — a haus desktop";

  # The whole desktop (system + shell + pounce + nebelung) comes from the public
  # haus flake. This private config holds only what's personal: the host.
  # Update everything with:  nix flake update haus
  inputs.haus.url = "github:hausfold/haus";

  outputs =
    { haus, ... }:
    {
      darwinConfigurations.mbp = haus.mkHaus {
        username = "julienmartel";
        hostname = "mbp";
        host = ./hosts/mbp;
      };
    };
}
