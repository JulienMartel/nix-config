# Added by pounce "Install App". Safe to edit or remove.
{ lib, pkgs, ... }:
{
  environment.systemPackages = [
    (lib.attrByPath (lib.splitString "." "htop")
      (throw ("pounce Install App: Nixpkgs package " + "htop" + " does not exist")) pkgs)
  ];
}
