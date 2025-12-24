{ config, pkgs, lib, sops-nix, ... }:
let
  immichSecrets = [
    "immich/oidc_client_id"
    "immich/oidc_client_secret"
  ];
in
{
  # Traefik dynamic configuration for Immich
  environment.etc."traefik/dynamic/immich.yml".text = ''
    http:
      routers:
        immich-http:
          rule: "Host(`photos.moritzwm.de`)"
          service: immich
          entryPoints:
            - web
          middlewares:
            - https-redirect

        immich-https:
          rule: "Host(`photos.moritzwm.de`)"
          service: immich
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt

      services:
        immich:
          loadBalancer:
            servers:
              - url: "http://10.233.3.2:2283"
            passHostHeader: true
  '';

  # NixOS container for Immich
  containers.immich = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.3.1";
    localAddress = "10.233.3.2";

    # Bind mount the age key so sops-nix can decrypt secrets inside the container
    bindMounts = {
      "/var/lib/sops-nix/keys.txt" = {
        hostPath = "/var/lib/sops-nix/keys.txt";
        isReadOnly = true;
      };
    };

    config = { config, pkgs, lib, ... }: {
      imports = [
        sops-nix.nixosModules.sops
      ];

      # Configure sops-nix inside the container
      sops = {
        defaultSopsFile = ./secrets.yaml;
        age.keyFile = "/var/lib/sops-nix/keys.txt";

        secrets = lib.genAttrs immichSecrets (name: {
          owner = "immich";
          group = "immich";
          mode = "0400";
        });
      };

      system.stateVersion = "25.11";
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 2283 ];
      };

      services.immich = {
        enable = true;
        host = "0.0.0.0";
        port = 2283;
        openFirewall = true;

        mediaLocation = "/var/lib/immich";

        environment = {
          IMMICH_LOG_LEVEL = "log";
        };

        machine-learning.enable = true;
      };

      # PostgreSQL is automatically configured by the Immich module
      # Redis is automatically configured by the Immich module

      services.postgresqlBackup = {
        enable = true;
        databases = [ "immich" ];
      };
    };
  };
}
