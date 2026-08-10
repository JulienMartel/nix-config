# Managed by haus set. Ordinary Nix: safe to inspect or edit.
# Remove this override with: haus reset sill.media.width
{ lib, ... }:

{
  haus.sill.media.width = lib.mkForce (builtins.fromJSON "60");
}
