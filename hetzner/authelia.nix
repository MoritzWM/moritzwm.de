{ config, pkgs, lib, sops-nix, ... }:
{
  # SOPS secrets for Authelia
  sops.secrets."authelia/jwt_secret" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."authelia/session_secret" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."authelia/storage_encryption_key" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."authelia/oidc_hmac_secret" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."authelia/jwks_private_key" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."nextcloud/oidc_client_id" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."nextcloud/oidc_client_secret" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."nextcloud/oidc_client_secret_hash" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

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

  # NixOS container for Authelia
  containers.authelia = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.2.1";
    localAddress = "10.233.2.2";

    # Bind mount decrypted secrets from host into container
    bindMounts = {
      "/var/lib/authelia-secrets" = {
        hostPath = "/run/secrets/authelia";
        isReadOnly = true;
      };
    };

    config = { config, pkgs, lib, sops-nix, ... }: {
      system.stateVersion = "25.11";

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 9091 ];
      };

      services.authelia.instances.main = {
        enable = true;
        secrets = {
          jwtSecretFile = "/var/lib/authelia-secrets/jwt_secret";
          storageEncryptionKeyFile = "/var/lib/authelia-secrets/storage_encryption_key";
          sessionSecretFile = "/var/lib/authelia-secrets/session_secret";
          oidcIssuerPrivateKeyFile = "/var/lib/authelia-secrets/jwks_private_key";
          oidcHmacSecretFile = "/var/lib/authelia-secrets/oidc_hmac_secret";
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

          notifier.filesystem.filename = "/var/lib/authelia-main/notification.txt";

          # OpenID Connect Provider for Nextcloud
          identity_providers.oidc = {
            clients = [{
              client_id = "${builtins.readFile config.sops.secrets."nextcloud/oidc_client_id".path}";
              client_name = "Nextcloud";
              client_secret = "${builtins.readFile config.sops.secrets."nextcloud/oidc_client_secret_hash".path}";
              public = false;
              authorization_policy = "two_factor";
              require_pkce = true;
              pkce_challenge_method = "S256";
              redirect_uris = [ "https://hetzner.moritzwm.de/apps/user_oidc/code" ];
              scopes = [ "openid" "profile" "email" "groups" ];
              response_types = [ "code" ];
              grant_types = [ "authorization_code" ];
              access_token_signed_response_alg = "none";
              userinfo_signed_response_alg = "none";
              token_endpoint_auth_method = "client_secret_post";
            }];
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
