{ config, pkgs, lib, sops-nix, ... }:
{
    users.groups.media.gid = 999;
    services.jellyfin = {
        enable = true;
        openFirewall = true;
        group = "media";
    };
}