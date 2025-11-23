{ config, pkgs, ... }:
{
    users.users.moritz = {
      isNormalUser = true;
      home = "/home/moritz";
      extraGroups = [ "wheel "];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqrx0JsGPUwEgiJqcXaPc4n7elVfq/mp4A9qIAOiXfg deck@steamdeck"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
        ];
  };
}
