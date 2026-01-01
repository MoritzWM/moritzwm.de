{ config, pkgs, lib, sops-nix, ... }:
{
    services.jellyfin = {
        enable = true;
        openFirewall = true;
    };
}