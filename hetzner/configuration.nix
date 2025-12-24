{
  modulesPath,
  lib,
  pkgs,
  sops-nix,
  ...
} @ args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    sops-nix.nixosModules.sops
    ./disk-config.nix
    ./traefik.nix
    ./nextcloud.nix
    ./authelia.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  networking.hostName = "hetzner";
  networking.domain = "moritzwm.de";
  services.openssh.enable = true;
  time.timeZone = "Europe/Berlin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.tmux
    pkgs.bottom
  ];
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-authelia" "ve-nextcloud" ];
    externalInterface = "enp1s0";
  };
  system.stateVersion = "25.11";
  zramSwap.enable = true;
  services.openssh.hostKeys = [
    {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
    }
  ];
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqrx0JsGPUwEgiJqcXaPc4n7elVfq/mp4A9qIAOiXfg deck@steamdeck"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
    ];
  };
  virtualisation.vmVariant = {
    virtualisation.sharedDirectories = {
      sops-key = {
        source = "$HOME/.config/sops/age";
        target = "/var/lib/sops-nix";
      };
    };

    users.users.vmuser = {
        isNormalUser = true;
        initialPassword = "vm";
        extraGroups = [ "wheel" ];
    };
  };
}
