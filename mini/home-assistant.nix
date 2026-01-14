{ config, pkgs, lib, sops-nix, ... }:
{ 
    networking.firewall.allowedTCPPorts = [ 1883 8123 ];
    virtualisation.oci-containers = {
        backend = "podman";
        containers.homeassistant = {
            volumes = [ "/home-assistant-config:/config" ];
            environment.TZ = "Europe/Berlin";
            image = "ghcr.io/home-assistant/home-assistant:stable";
            extraOptions = [ 
                "--network=host" 
                # "--device=/dev/ttyACM0:/dev/ttyACM0"	# Example, change this to match your own hardware
            ];
        };
	};
    sops.secrets."mqtt/homeassistant_pass" = {};
    sops.secrets."mqtt/valetudo_pass" = {};
    services.mosquitto = {
        enable = true;
        listeners = [{
            users.homeassistant = {
                passwordFile = config.sops.secrets."mqtt/homeassistant_pass".path;
                acl = [
                    "readwrite #"
                ];
            };
            users.valetudo = {
                passwordFile = config.sops.secrets."mqtt/valetudo_pass".path;
                acl = [
                    "readwrite #"
                ];
            };
        }];
    };
}
