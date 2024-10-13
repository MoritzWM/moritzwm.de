{ config, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ./user-moritz.nix
      ./nextcloud.nix
      ./fail2ban.nix
      ./vaultwarden.nix
      ./tor.nix
      ./paperless.nix
      ./pgsql_upgrade.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "v2202205176338190863";
  networking.domain = "megasrv.de";
  networking.useDHCP = false;
  networking.interfaces.ens3.useDHCP = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  environment.systemPackages = with pkgs; [
    tmux
    bottom
  ];
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };
  programs.git.enable = true;
  services.openssh.enable = true;
  system.stateVersion = "24.05";
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  zramSwap.enable = true;
  # system.autoUpgrade.enable = true;
  # system.autoUpgrade.allowReboot = true;

}

