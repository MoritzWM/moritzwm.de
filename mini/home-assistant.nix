{ config, pkgs, lib, sops-nix, ... }:
{
    services.home-assistant = {
        enable = true;
        openFirewall = true;
        config.homeassistant.time_zone = "Europe/Berlin";
    }
}
