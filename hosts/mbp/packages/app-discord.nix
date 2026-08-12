# Added by pounce "Install App". Safe to edit or remove.
{ lib, ... }:
{
  haus.roster."discord" = {
    enable = lib.mkDefault true;
    order = lib.mkDefault 1000;
    key = lib.mkDefault "a";
    name = lib.mkDefault "Discord";
    appId = lib.mkDefault null;
    label = lib.mkDefault "Discord";
    cask = lib.mkDefault "discord";
  };
}
