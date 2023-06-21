{ config, pkgs, ... }:
{
  services.tor = {
    enable = true;
    relay.enable = true;
    settings.ORPort = [
      {
        port = 40000;
        IPv4Only = true;
      }
    ];
    settings.ContactInfo = "tor@moritzwm.de";
    openFirewall = true;
    relay.role = "relay";
  };
}
