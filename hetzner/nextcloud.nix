{ config, pkgs, lib, sops-nix, ... }:
let
  nextcloudSecrets = [
    "nextcloud/admin_pass"
    "nextcloud/oidc_client_id"
    "nextcloud/oidc_client_secret"
  ];
in
{
  environment.etc."traefik/dynamic/nextcloud.yml".text = ''
    http:
      routers:
        nextcloud-http:
          rule: "Host(`hetzner.moritzwm.de`)"
          service: nextcloud
          entryPoints:
            - web
          middlewares:
            - nextcloud-headers
            - https-redirect

        nextcloud-https:
          rule: "Host(`hetzner.moritzwm.de`)"
          service: nextcloud
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt
          middlewares:
            - nextcloud-headers
            - nextcloud-redirectregex

      services:
        nextcloud:
          loadBalancer:
            servers:
              - url: "http://10.233.1.2:80"
            passHostHeader: true

      middlewares:
        https-redirect:
          redirectScheme:
            scheme: https
            permanent: true
        nextcloud-redirectregex:
          redirectRegex:
            permanent: true
            regex: "https://(.*)/.well-known/(card|cal)dav"
            replacement: "https://$$1/remote.php/dav/"
        nextcloud-headers:
          headers:
            customFrameOptionsValue: SAMEORIGIN
            customRequestHeaders:
              Strict-Transport-Security: 15552000
  '';

  # NixOS container for Nextcloud
  containers.nextcloud = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.1.1";
    localAddress = "10.233.1.2";

    # Bind mount the age key so sops-nix can decrypt secrets inside the container
    bindMounts = {
      "/var/lib/sops-nix/keys.txt" = {
        hostPath = "/var/lib/sops-nix/keys.txt";
        isReadOnly = true;
      };
      "/var/lib/nextcloud/data" = {
        hostPath = "/mnt/storagebox_nextcloud";
        isReadOnly = false;
      };
    };

    config = { config, pkgs, lib, ... }: {
      imports = [
        sops-nix.nixosModules.sops
      ];
      systemd.tmpfiles.rules = [ "d /var/lib/nextcloud 700 nextcloud nextcloud -" ];

      # Configure sops-nix inside the container
      sops = {
        defaultSopsFile = ./secrets.yaml;
        age.keyFile = "/var/lib/sops-nix/keys.txt";

        # Nextcloud secrets owned by nextcloud user
        secrets = lib.genAttrs nextcloudSecrets (name: {
          owner = "nextcloud";
          group = "nextcloud";
          mode = "0400";
        });
      };

      system.stateVersion = "25.11";
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      # Networking inside container
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 80 ];
      };

      # PostgreSQL database
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_15;
        ensureDatabases = [ "nextcloud" ];
        ensureUsers = [{
          name = "nextcloud";
          ensureDBOwnership = true;
        }];
      };

      # Nextcloud service
      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud32;
        hostName = "hetzner.moritzwm.de";
        
        extraAppsEnable = true;
        extraApps = {
            inherit (config.services.nextcloud.package.packages.apps) contacts calendar tasks user_oidc;
        };

        config = {
          dbtype = "pgsql";
          dbuser = "nextcloud";
          dbhost = "/run/postgresql";
          dbname = "nextcloud";
          adminuser = "moritz-admin";
          adminpassFile = config.sops.secrets."nextcloud/admin_pass".path;
        };

        settings = {
          overwriteprotocol = "https";
          trusted_proxies = [ "10.233.1.1" ];
          default_phone_region = "DE";
          social_login_auto_redirect = true;
          lost_password_link = "disabled";
          user_oidc = {
            default_token_endpoint_auth_method = "client_secret_post";
          };
        };

        # PHP settings for better performance
        phpOptions = {
          "opcache.enable" = "1";
          "opcache.interned_strings_buffer" = "32";
          "upload_max_filesize" = lib.mkForce "16G";
          "post_max_size" = lib.mkForce "16G";
        };
      };

      systemd.services."nextcloud-setup" = {
        requires = ["postgresql.service"];
        after = ["postgresql.service"];
      };

      # Automatically initialize OIDC provider
      systemd.services.nextcloud-init-oidc = {
        wantedBy = [ "multi-user.target" ];
        after = [ "nextcloud-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${config.services.nextcloud.occ}/bin/nextcloud-occ user_oidc:provider Authelia\
            --clientid="$(cat ${config.sops.secrets."nextcloud/oidc_client_id".path})"\
            --clientsecret="$(cat ${config.sops.secrets."nextcloud/oidc_client_secret".path})"\
            --discoveryuri='https://auth.moritzwm.de/.well-known/openid-configuration'
        '';
      };

      services.postgresqlBackup = {
        enable = true;
        databases = [ "nextcloud" ];
      };
    };
  };
}
