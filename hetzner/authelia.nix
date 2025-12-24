{ config, pkgs, lib, sops-nix, ... }:
let
  # Define authelia secrets with proper ownership for the container
  autheliaSecrets = [
    "authelia/jwt_secret"
    "authelia/session_secret"
    "authelia/storage_encryption_key"
    "authelia/oidc_hmac_secret"
    "authelia/jwks_private_key"
    "authelia/smtp_password"
  ];
  oidcSecrets = [
    "nextcloud/oidc_client_id"
    "nextcloud/oidc_client_secret_hash"
    "immich/oidc_client_id"
    "immich/oidc_client_secret_hash"
  ];
in
{
  # Traefik dynamic configuration for Authelia
  environment.etc."traefik/dynamic/authelia.yml".text = ''
    http:
      routers:
        authelia-http:
          rule: "Host(`auth.moritzwm.de`)"
          service: authelia
          entryPoints:
            - web
          middlewares:
            - https-redirect

        authelia:
          rule: "Host(`auth.moritzwm.de`)"
          service: authelia
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt

      services:
        authelia:
          loadBalancer:
            servers:
              - url: "http://10.233.2.2:9091"

      middlewares:
        https-redirect:
          redirectScheme:
            scheme: https
            # permanent: true

        authelia:
          forwardAuth:
            address: "http://10.233.2.2:9091/api/authz/forward-auth"
            trustForwardHeader: true
            authResponseHeaders:
              - Remote-User
              - Remote-Groups
              - Remote-Name
              - Remote-Email
  '';

  containers.authelia = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.2.1";
    localAddress = "10.233.2.2";

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

        # Authelia secrets owned by authelia user
        secrets = lib.genAttrs autheliaSecrets (name: {
          owner = "authelia-main";
          group = "authelia-main";
          mode = "0400";
        }) // lib.genAttrs oidcSecrets (name: {
          owner = "authelia-main";
          group = "authelia-main";
          mode = "0400";
        });
      };
      system.stateVersion = "25.11";

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 9091 ];
      };
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      services.authelia.instances.main = {
        enable = true;
        secrets = {
          jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
          storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
          sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
          oidcIssuerPrivateKeyFile = config.sops.secrets."authelia/jwks_private_key".path;
          oidcHmacSecretFile = config.sops.secrets."authelia/oidc_hmac_secret".path;
        };
        settings = {
          theme = "dark";

          server = {
            address = "tcp://0.0.0.0:9091/";
          };

          log = {
            level = "info";
            format = "text";
          };

          totp = {
            issuer = "moritzwm.de";
            period = 30;
            skew = 1;
          };

          authentication_backend.file = {
            path = "/var/lib/authelia-main/users.yml";
          };

          access_control = {
            default_policy = "deny";
            rules = [
              { domain = "hetzner.moritzwm.de"; policy = "two_factor"; }
              { domain = "photos.moritzwm.de"; policy = "two_factor"; }
              { domain = "auth.moritzwm.de"; policy = "bypass"; }
            ];
          };

          session = {
            name = "authelia_session";
            cookies = [{
              domain = "moritzwm.de";
              authelia_url = "https://auth.moritzwm.de";
            }];
            expiration = "1h";
            inactivity = "5m";
            remember_me = "1M";
          };

          regulation = {
            max_retries = 3;
            find_time = "2m";
            ban_time = "5m";
          };

          storage.local.path = "/var/lib/authelia-main/db.sqlite3";

          notifier.smtp = {
            address = "submission://mxe93e.netcup.net:587";
            username = "noreply@moritzwm.de";
            password = ''{{ secret "${config.sops.secrets."authelia/smtp_password".path}" }}'';
            sender = "Authelia <noreply@moritzwm.de>";
          };

          # OpenID Connect Provider
          identity_providers.oidc = {
            clients = [
              {
                client_id = ''{{ secret "${config.sops.secrets."nextcloud/oidc_client_id".path}" }}'';
                client_name = "Nextcloud";
                client_secret = ''{{ secret "${config.sops.secrets."nextcloud/oidc_client_secret_hash".path}" }}'';
                public = false;
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                require_pkce = true;
                pkce_challenge_method = "S256";
                redirect_uris = [ "https://hetzner.moritzwm.de/apps/user_oidc/code" ];
                scopes = [ "openid" "profile" "email" "groups" ];
                response_types = [ "code" ];
                grant_types = [ "authorization_code" ];
                access_token_signed_response_alg = "none";
                userinfo_signed_response_alg = "none";
                token_endpoint_auth_method = "client_secret_post";
              }
              {
                client_id = ''{{ secret "${config.sops.secrets."immich/oidc_client_id".path}" }}'';
                client_name = "Immich";
                client_secret = ''{{ secret "${config.sops.secrets."immich/oidc_client_secret_hash".path}" }}'';
                public = false;
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                require_pkce = true;
                pkce_challenge_method = "S256";
                redirect_uris = [
                  "https://photos.moritzwm.de/auth/login"
                  "https://photos.moritzwm.de/user-settings"
                  "app.immich:///oauth-callback"
                ];
                scopes = [ "openid" "profile" "email" ];
                response_types = [ "code" ];
                grant_types = [ "authorization_code" ];
                access_token_signed_response_alg = "none";
                userinfo_signed_response_alg = "none";
                token_endpoint_auth_method = "client_secret_post";
              }
            ];
          };
        };
      };

      # Create users file if it doesn't exist
      systemd.services.authelia-init-users = {
        wantedBy = [ "multi-user.target" ];
        before = [ "authelia-main.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          SECRETS_DIR="/var/lib/authelia-main"
          mkdir -p "$SECRETS_DIR"

          # Create users file if it doesn't exist
          if [ ! -f "$SECRETS_DIR/users.yml" ]; then
            cat > "$SECRETS_DIR/users.yml" << 'USERS'
          users:
            moritz:
              displayname: "Moritz"
              password: "$argon2id$v=19$m=65536,t=3,p=4$MHlJcrzfED1a/Fj+MKFPTQ$9EsBLzZxidWCjnIAblNYdKdrCqdJjEHILC0bbw9NNQA"
              email: mail@moritzwm.de
              groups:
                - admins
                - users
          USERS
            chmod 600 "$SECRETS_DIR/users.yml"
            echo "Created users.yml template - please update the password hash!"
          fi
        '';
      };
    };
  };
}
