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
	services.openssh.enable = true;
	time.timeZone = "Europe/Berlin";

	nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;
	environment.systemPackages = map lib.lowPrio [
		pkgs.curl
		pkgs.gitMinimal
		pkgs.tmux
		pkgs.bottom
		pkgs.vim
	];
	system.stateVersion = "25.11";
	zramSwap.enable = true;
	services.openssh.hostKeys = [
		{
			path = "/etc/ssh/ssh_host_ed25519_key";
			type = "ed25519";
		}
	];
	# sops = {
		# defaultSopsFile = ./secrets.yaml;
		# age.keyFile = "/var/lib/sops-nix/keys.txt";
	# };
	users.users.root = {
		openssh.authorizedKeys.keys = [
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqrx0JsGPUwEgiJqcXaPc4n7elVfq/mp4A9qIAOiXfg deck@steamdeck"
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpKJNbeP/AReFpACmNIvfbpukdm2BwpnmOVszlxDVMj moritz@moritz-arch"
		];
	};

	swapDevices = [{
		device = "/var/lib/swapfile";
		size = 16*1024; # 16 GB
		}];

	fileSystems.hub = {
		mountPoint = "/hub";
		device = "UUID=b5aa426e-5840-4ccf-a303-250c65e23dd5";
		fsType = "btrfs";
		options = [
			"defaults"
			"auto"
			"nofail"
			"compress=zstd"
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
