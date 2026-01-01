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
    services.sabnzbd = {
        enable = true;
        openFirewall = true;
        group = "media";
    };
}
