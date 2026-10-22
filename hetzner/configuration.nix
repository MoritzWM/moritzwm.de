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
    "hetzner/immich_smb_user"
    "hetzner/immich_smb_pass"
    "hetzner/nextcloud_smb_user"
    "hetzner/nextcloud_smb_pass"
    "hetzner/paperless_smb_user"
    "hetzner/paperless_smb_pass"
    "hetzner/wireguard_private_key"
    "hetzner/wireguard_preshared_key"
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
    ./mealie.nix
    ./paperless.nix
    ./actual.nix
    ./backup.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  networking.hostName = "hetzner";
  networking.domain = "moritzwm.de";
  networking.interfaces.enp1s0.ipv6.addresses = [{
    address = "2a01:4f8:c0c:5a19::2";
    prefixLength = 64;
  }];
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "enp1s0";
  };
  networking.wireguard.interfaces.wg-home = {
    ips = [
      "192.168.178.201/24"
      "fd64:ccc0:9a33::201/64"
    ];
    privateKeyFile = config.sops.secrets."hetzner/wireguard_private_key".path;
    peers = [{
      publicKey = "uUJN3l48VhNWaHw66oZ4nvFCdvuQ2Y6KYcOLDxVLq2w=";
      presharedKeyFile = config.sops.secrets."hetzner/wireguard_preshared_key".path;
      allowedIPs = [
        "192.168.178.0/24"
        "fd64:ccc0:9a33::/64"
      ];
      endpoint = "pec1mvdw2mugnb21.myfritz.net:51102";
      persistentKeepalive = 25;
    }];
  };
  services.openssh.enable = true;
  time.timeZone = "Europe/Berlin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.tmux
    pkgs.bottom
    pkgs.borgbackup
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
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/run/secrets.d/age-keys.txt";
    secrets = lib.genAttrs hetznerSecrets (name: {
      owner = "root";
      group = "root";
      mode = "0400";
    });
    templates."immich_storagebox_smbcredentials".content = ''
      username=${config.sops.placeholder."hetzner/immich_smb_user"}
      password=${config.sops.placeholder."hetzner/immich_smb_pass"}
    '';
    templates."paperless_storagebox_smbcredentials".content = ''
      username=${config.sops.placeholder."hetzner/paperless_smb_user"}
      password=${config.sops.placeholder."hetzner/paperless_smb_pass"}
    '';
    templates."nextcloud_storagebox_smbcredentials".content = ''
      username=${config.sops.placeholder."hetzner/nextcloud_smb_user"}
      password=${config.sops.placeholder."hetzner/nextcloud_smb_pass"}
    '';
  };
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUI69bmgKa3TJC9tCTeB60X3dy4xgl3d5s7Ag3+0wq6 moritz@htpc"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqrx0JsGPUwEgiJqcXaPc4n7elVfq/mp4A9qIAOiXfg deck@steamdeck"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBT6sgrPY9DYzKWil6zdVnFhD1AiS78OjaK6xTIt5Hx5 root@mini"
  ];
  };
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  fileSystems."/mnt/storagebox_nextcloud" = {
    device = "//u523451-sub2.your-storagebox.de/u523451-sub2";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."nextcloud_storagebox_smbcredentials".path}"
      "uid=999"
      "gid=999"
      "file_mode=0770"
      "dir_mode=0770"
      "x-systemd.automount"
    ];
  };
  fileSystems."/mnt/storagebox_immich" = {
    device = "//u523451-sub1.your-storagebox.de/u523451-sub1";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."immich_storagebox_smbcredentials".path}"
      "uid=999"
      "gid=999"
      "file_mode=0770"
      "dir_mode=0770"
      "x-systemd.automount"
    ];
  };
  fileSystems."/mnt/storagebox_paperless" = {
    device = "//u523451-sub3.your-storagebox.de/u523451-sub3";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."paperless_storagebox_smbcredentials".path}"
      "uid=999"
      "gid=999"
      "file_mode=0770"
      "dir_mode=0770"
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
