{
  modulesPath,
  lib,
  pkgs,
  ...
} @ args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./traefik.nix
    ./nextcloud.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  networking.hostName = "hetzner";
  networking.domain = "moritzwm.de";
  services.openssh.enable = true;
  time.timeZone = "Europe/Berlin";

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.tmux
    pkgs.bottom
  ];
  system.stateVersion = "25.11";
  zramSwap.enable = true;
  users.users.root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqrx0JsGPUwEgiJqcXaPc4n7elVfq/mp4A9qIAOiXfg deck@steamdeck"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
        ];
  };
}
