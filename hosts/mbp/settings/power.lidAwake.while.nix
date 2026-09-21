# Managed by haus set. Ordinary Nix: safe to inspect or edit.
# Remove this override with: haus reset power.lidAwake.while
{ lib, ... }:

{
  haus.power.lidAwake.while = lib.mkForce ("agents");
}
