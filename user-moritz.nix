{ config, pkgs, ... }:
{
  users.users.moritz = {
    isNormalUser = true;
    home = "/home/moritz";
    extraGroups = [ "wheel" "nextcloud" "paperless" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUI69bmgKa3TJC9tCTeB60X3dy4xgl3d5s7Ag3+0wq6 moritz@htpc"
    ];
  };
}
