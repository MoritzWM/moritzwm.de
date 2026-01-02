# My NixOS configuration

## Installation and updates

Al relevant tasks are in `.vscode/tasks.json`.

## Hosts

### Hetzner

My VPS running a few nice services.


### Mini

A mini PC running at home.

## Other notes

`sops.age.generateKey = true` does not seem to work with auto-generated SSH host keys, see [this issue](https://github.com/Mic92/sops-nix/issues/167).
Therefore, it has to be generated manually:
```
nix-shell -p ssh-to-age --run 'ssh-to-age -private-key -i ssh_host_ed25519_key' > keys.txt
```