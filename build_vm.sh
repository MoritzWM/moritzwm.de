# nix run github:nix-community/nixos-anywhere -- --flake .#hetzner --vm-test
set -e
nix run nixpkgs#nixos-rebuild -- build-vm --flake .#hetzner
./result/bin/run-hetzner-vm
rm hetzner.qcow2
