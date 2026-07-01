{
  description = "julienmartel's machine — a nebelhaus";

  # The whole rice (system + shell + pounce + nebelung) comes from the public
  # nebelhaus flake. This private config holds only what's personal: the host.
  # Update everything with:  nix flake update nebelhaus
  inputs.nebelhaus.url = "github:nebelhaus/nebelhaus";

  outputs =
    { nebelhaus, ... }:
    {
      darwinConfigurations.mbp = nebelhaus.mkNebelhaus {
        username = "julienmartel";
        hostname = "mbp";
        host = ./hosts/mbp;
      };
    };
}
