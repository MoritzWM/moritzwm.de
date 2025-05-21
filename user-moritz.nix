{ config, pkgs, ... }:
{
  users.users.moritz = {
    isNormalUser = true;
    home = "/home/moritz";
    extraGroups = [ "wheel" "nextcloud" "paperless" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBa68lr6VIyXXGL4XUgwTaPuH3hc7+3r8eTtkYH9ABac moritz@moritz-arch-mini"
    ];
  };
}
