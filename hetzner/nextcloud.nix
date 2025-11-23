{ config, pkgs, lib, ... }:
{
  environment.etc."traefik/dynamic/nextcloud.yml".text = ''
    http:
      routers:
        nextcloud:
          rule: "Host(`hetzner.moritzwm.de`)"
          entryPoints:
            - websecure
          service: nextcloud
          tls:
            certResolver: letsencrypt

      services:
        nextcloud:
          loadBalancer:
            servers:
              - url: "http://10.233.1.2:80"

      middlewares:
        nextcloud-redirectregex:
          redirectRegex:
            permanent: true
            regex: "https://(.*)/.well-known/(card|cal)dav"
            replacement: "https://$$1/remote.php/dav/"
  '';

  # NixOS container for Nextcloud
  containers.nextcloud = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.1.1";
    localAddress = "10.233.1.2";

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";

      # Networking inside container
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 80 ];
      };

      # PostgreSQL database
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "nextcloud" ];
        ensureUsers = [{
          name = "nextcloud";
          ensureDBOwnership = true;
        }];
      };

      # Nextcloud service
      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud30;
        hostName = "hetzner.moritzwm.de";  # Change this to your domain

        config = {
          dbtype = "pgsql";
          dbuser = "nextcloud";
          dbhost = "/run/postgresql";
          dbname = "nextcloud";

          adminuser = "admin";
          adminpassFile = "/var/lib/nextcloud/admin-pass";
        };

        settings = {
          overwriteprotocol = "https";
          trusted_proxies = [ "10.233.1.1" ];
          default_phone_region = "DE";
        };

        # Enable common apps
        # extraApps = with config.services.nextcloud.package.packages.apps; {
          # inherit contacts calendar tasks notes;
        # };
        # extraAppsEnable = true;

        # PHP settings for better performance
        phpOptions = {
          "opcache.enable" = "1";
          "opcache.interned_strings_buffer" = "16";
          "opcache.max_accelerated_files" = "10000";
          "opcache.memory_consumption" = "128";
          "opcache.save_comments" = "1";
          "opcache.revalidate_freq" = "1";
          "memory_limit" = "512M";
          "upload_max_filesize" = "16G";
          "post_max_size" = "16G";
          "max_execution_time" = "300";
        };

        # Enable nginx inside container
        nginx.enable = true;
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
          if [ ! -f /var/lib/nextcloud/admin-pass ]; then
            mkdir -p /var/lib/nextcloud
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
