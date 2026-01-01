{ config, pkgs, lib, sops-nix, ... }:
{
    services.sonarr = {
        enable = true;
        openFirewall = true;
    };
    services.radarr = {
        enable = true;
        openFirewall = true;
    };
    services.sabnzbd = {
        enable = true;
        openFirewall = true;
    };
}
