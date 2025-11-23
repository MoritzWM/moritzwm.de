{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  outputs =
    {
      nixpkgs,
      disko,
      nixos-facter-modules,
      ...
    }:
    {
      nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hetzner/configuration.nix
          ./hetzner/hardware-configuration.nix
        ];
      };
    };
}
