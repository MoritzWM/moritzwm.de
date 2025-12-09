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
        # TODO change back to 31
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

          # OpenID Connect Login via Authelia
          lost_password_link = "disabled";
          oidc_login_provider_url = "https://auth.moritzwm.de";
          oidc_login_logout_url = "https://auth.moritzwm.de/logout";
          oidc_login_client_id = "nextcloud";
          oidc_login_client_secret = "Ou6oothiAhlie8ChBeebo3peXu6gahvowe8PeeSezae7feiYvooShaR3Il2beo9f";
          oidc_login_auto_redirect = false;  # Set to true to skip Nextcloud login page
          oidc_login_end_session_redirect = false;
          oidc_login_button_text = "Log in with Authelia";
          oidc_login_hide_password_form = false;
          oidc_login_use_id_token = false;
          oidc_login_attributes = {
            id = "preferred_username";
            name = "name";
            mail = "email";
            groups = "groups";
          };
          oidc_login_default_group = "oidc";
          oidc_login_use_external_storage = false;
          oidc_login_scope = "openid profile email groups nextcloud_userinfo";
          oidc_login_proxy_ldap = false;
          oidc_login_disable_registration = true;
          oidc_login_redir_fallback = false;
          oidc_login_tls_verify = true;
          oidc_create_groups = false;
          oidc_login_webdav_enabled = false;
          oidc_login_password_authentication = false;
          oidc_login_public_key_caching_time = 86400;
          oidc_login_min_time_between_jwks_requests = 10;
          oidc_login_well_known_caching_time = 86400;
          oidc_login_update_avatar = false;
          oidc_login_code_challenge_method = "S256";
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

          # Create placeholder for OIDC secret if it doesn't exist
          # NOTE: Copy the secret from /var/lib/authelia-main/oidc_nextcloud_secret on the host
          if [ ! -f /var/lib/nextcloud/oidc_secret ]; then
            echo "REPLACE_WITH_AUTHELIA_OIDC_SECRET" > /var/lib/nextcloud/oidc_secret
            chmod 600 /var/lib/nextcloud/oidc_secret
            echo "Created OIDC secret placeholder."
            echo "IMPORTANT: Copy the secret from the Authelia container:"
            echo "  nixos-container run authelia -- cat /var/lib/authelia-main/oidc_nextcloud_secret"
            echo "Then paste it into the Nextcloud container:"
            echo "  nixos-container run nextcloud -- tee /var/lib/nextcloud/oidc_secret"
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
