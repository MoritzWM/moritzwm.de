{ config, pkgs, lib, sops-nix, ... }:
{
    services.sonarr = {
        enable = true;
        openFirewall = true;
        group = "media";
    };
    services.radarr = {
        enable = true;
        openFirewall = true;
        group = "media";
    };

    networking.firewall.allowedTCPPorts = [ 8085 ];
    services.sabnzbd = {
        enable = true;
        group = "media";
    };
}
