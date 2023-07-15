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
    # I have 80 TB of traffic per month -> 30 MB/s -> 15 MB/s for send/receive + some buffer
    settings.RelayBandwidthRate = "12 MBytes";
    openFirewall = true;
    relay.role = "relay";
  };
}
