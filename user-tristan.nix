{ config, pkgs, ... }:
{
  users.users.tristan = {
    isNormalUser = true;
    home = "/home/tristan";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBR5a2/VPKF+8JyKCDJ5p78z7xJSvxilepy6MI8cG684 netcup-tristan"
    ];
  };
}
