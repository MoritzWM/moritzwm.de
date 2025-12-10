{ config, pkgs, lib, ... }:
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
            - authelia
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

    config = { config, pkgs, lib, ... }: {
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
        
        extraApps = {
            inherit (config.services.nextcloud.package.packages.apps) contacts calendar tasks user_oidc;
        };
        extraAppsEnable = true;

        config = {
          dbtype = "pgsql";
          dbuser = "nextcloud";
          dbhost = "/run/postgresql";
          dbname = "nextcloud";
          adminuser = "moritz-admin";
          adminpassFile = "/var/lib/nextcloud/admin-pass";
        };

        settings = {
          overwriteprotocol = "https";
          trusted_proxies = [ "10.233.1.1" ];
          default_phone_region = "DE";
          lost_password_link = "disabled";
          user_oidc = {
            default_token_endpoint_auth_method = "client_secret_post";
          };
        };

        # PHP settings for better performance
        phpOptions = {
          "opcache.enable" = "1";
          "opcache.interned_strings_buffer" = "16";
          "opcache.max_accelerated_files" = "10000";
          "opcache.memory_consumption" = "128";
          "opcache.save_comments" = "1";
          "opcache.revalidate_freq" = "1";
          "memory_limit" = "512M";
          "upload_max_filesize" = lib.mkForce "16G";
          "post_max_size" = lib.mkForce "16G";
          "max_execution_time" = "300";
        };
      };

      systemd.services."nextcloud-setup" = {
        requires = ["postgresql.service"];
        after = ["postgresql.service"];
      };

      # Automatically initialize admin password if not exists
      systemd.services.nextcloud-init-pass = {
        wantedBy = [ "multi-user.target" ];
        before = [ "nextcloud-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /var/lib/nextcloud

          if [ ! -f /var/lib/nextcloud/admin-pass ]; then
            echo "juWah9UgeeSh9du3Ied7du0bWaiy5uudeez6oMei!" > /var/lib/nextcloud/admin-pass
            chmod 600 /var/lib/nextcloud/admin-pass
            echo "Generated initial admin password. Please change it after first login!"
          fi
        '';
      };

      services.postgresqlBackup = {
        enable = true;
        databases = [ "nextcloud" ];
      };
    };
  };
}
