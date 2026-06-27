{
	config,
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
        ./arr.nix
        ./jellyfin.nix
        ./home-assistant.nix
		./hardware-configuration.nix
	];
	boot.loader.grub = {
		efiSupport = true;
		efiInstallAsRemovable = true;
	};
	networking.hostName = "mini";
	networking.firewall.allowedTCPPorts = [ 111 2049 20048 5201];
	networking.firewall.allowedUDPPorts = [ 111 2049 20048 ];
	services.openssh.enable = true;
	time.timeZone = "Europe/Berlin";

	nix.settings.experimental-features = [ "nix-command" "flakes" ];
	nix.settings.auto-optimise-store = true;
	nix.gc = {
		automatic = true;
		dates = "weekly";
		options = "--delete-older-than 14d";
	};
    nixpkgs.config.allowUnfree = true;
	environment.systemPackages = map lib.lowPrio [
		pkgs.curl
		pkgs.gitMinimal
		pkgs.tmux
		pkgs.bottom
		pkgs.vim
		pkgs.jellyfin-mpv-shim
		pkgs.bluez
		pkgs.pavucontrol
	];
	system.stateVersion = "25.11";
	system.autoUpgrade = {
    enable = true;
    flake = "/var/lib/nixos-config#mini";
    flags = [ "--print-build-logs" ];
    dates = "05:00";
    operation = "switch";
    allowReboot = true;
  };

	# Audio
	services.pipewire = {
		enable = true;
		alsa.enable = true;
		pulse.enable = true;
  };

	# Bluetooth
	hardware.bluetooth.enable = true;

	# Minimal desktop for jellyfin-mpv-shim
	services.xserver.enable = true;
	services.xserver.windowManager.openbox.enable = true;
	# services.desktopManager.gnome.enable = true;
	# services.gnome.core-apps.enable = false;
	services.displayManager.autoLogin = {
		enable = true;
		user = "media";
	};
	# services.displayManager.defaultSession = "gnome";
	services.displayManager.defaultSession = "none+openbox";
	users.users.media = {
		isNormalUser = true;
		extraGroups = [ "video" "audio" ];
	};
	environment.etc."xdg/autostart/jellyfin-mpv-shim.desktop".text = ''
		[Desktop Entry]
		Name=Jellyfin MPV Shim
		Exec=sh -c 'sleep 30; jellyfin-mpv-shim'
		Type=Application
	'';
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
	};

	services.nfs.server = {
		enable = true;
		exports = ''
			/export 192.168.178.0/24(rw,fsid=0,insecure,no_root_squash,no_subtree_check)
			/export/Photos 192.168.178.0/24(rw,nohide,insecure,no_root_squash,no_subtree_check)
		'';
	};

	users.users.root = {
		openssh.authorizedKeys.keys = [
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUI69bmgKa3TJC9tCTeB60X3dy4xgl3d5s7Ag3+0wq6 moritz@htpc"
		];
	};

	swapDevices = [{
		device = "/var/lib/swapfile";
		size = 16*1024; # 16 GB
		}];

	fileSystems."/hub" = {
		device = "UUID=b5aa426e-5840-4ccf-a303-250c65e23dd5";
		fsType = "btrfs";
		options = [
			"defaults"
			"auto"
			"nofail"
			"compress=zstd"
		];
	};

	fileSystems."/export/Photos" = {
		device = "/hub/Photos";
		fsType = "none";
		options = [ "bind" ];
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
