{ config, pkgs, ... }:
{
  services.tor = {
    enable = true;
    relay.enable = true;
    settings.ORPort = "auto";
    relay.role = "relay";
  };
}
