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
    ./hetzner/disk-config.nix
    ./hetzner/user-moritz.nix
    ./hetzner/traefik.nix
    ./hetzner/nextcloud.nix
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
}
