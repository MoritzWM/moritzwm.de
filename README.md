# Installation and update

## Initial installation with nixos-anywhere

```
nix run github:nix-community/nixos-anywhere -- --flake .#name_of_flake --target-host name_of_host
# optional: --generate-hardware-config nixos-generate-config ./hardware-configuration.nix
```

`sops.age.generateKey = true` does not seem to work with auto-generated SSH host keys, see [this issue](https://github.com/Mic92/sops-nix/issues/167).
Therefore, it has to be generated manually:
```
nix-shell -p ssh-to-age --run 'ssh-to-age -private-key -i ssh_host_ed25519_key' > keys.txt
```

## Update

From local machine
```
nix run nixpkgs#nixos-rebuild -- switch --flake ./#hetzner --target-host hetzner
```
On remote machine
```
nixos-rebuild switch --flake ./#hetzner
```