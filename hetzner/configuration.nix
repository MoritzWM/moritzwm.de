{
  config,
  modulesPath,
  lib,
  pkgs,
  sops-nix,
  ...
} @ args:
let
  hetznerSecrets = [
    "hetzner/smb_user"
    "hetzner/smb_pass"
  ];
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    sops-nix.nixosModules.sops
    ./disk-config.nix
    ./traefik.nix
    ./nextcloud.nix
    ./authelia.nix
    ./immich.nix
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
    internalInterfaces = [ "ve-authelia" "ve-nextcloud" "ve-immich" ];
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
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/keys.txt";
    secrets = lib.genAttrs hetznerSecrets (name: {
      owner = "root";
      group = "root";
      mode = "0400";
    });
    templates."storagebox_smbcredentials".content = ''
      username=${config.sops.placeholder."hetzner/smb_user"}
      password=${config.sops.placeholder."hetzner/smb_pass"}
    '';
  };
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqrx0JsGPUwEgiJqcXaPc4n7elVfq/mp4A9qIAOiXfg deck@steamdeck"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
    ];
  };

  fileSystems."/mnt/storagebox" = {
      device = "//u523451-sub1.your-storagebox.de/u523451-sub1";
      fsType = "cifs";
      options = [
        "credentials=${config.sops.templates."storagebox_smbcredentials".path}"
        "uid=0"
        "gid=0"
        "file_mode=0755"
        "dir_mode=0755"
        "x-systemd.automount"
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
