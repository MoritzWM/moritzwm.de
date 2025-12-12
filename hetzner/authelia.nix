{ config, pkgs, lib, ... }:
{
  # Traefik dynamic configuration for Authelia
  environment.etc."traefik/dynamic/authelia.yml".text = ''
    http:
      routers:
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

    config = { config, pkgs, lib, ... }: {
      system.stateVersion = "25.11";

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 9091 ];
      };

      services.authelia.instances.main = {
        enable = true;
        secrets = {
          jwtSecretFile = "/var/lib/authelia-main/jwt_secret";
          storageEncryptionKeyFile = "/var/lib/authelia-main/storage_encryption_key";
          sessionSecretFile = "/var/lib/authelia-main/session_secret";
          oidcIssuerPrivateKeyFile = "/var/lib/authelia-main/jwks_private.pem";
          oidcHmacSecretFile = "/var/lib/authelia-main/oidc_hmac_secret";
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
            # TODO add JWKS
            # TODO move to secret
            clients = [{
              # TODO change
              # https://www.authelia.com/integration/openid-connect/frequently-asked-questions/#how-do-i-generate-a-client-identifier-or-client-secret
              # Random Password: boq0fc_mb4e~ht5zmA5iF7Qiq33saCiqE-OOTV2v4SdQnuiXk08xSr42p96hHcCuGDjyNooO
              # Digest: $pbkdf2-sha512$310000$6/TDVR1IzGQfrtE6yNCFvA$OiN8pG3.q3/TAdTQ8rJMD9KRDJ1DJIfqlw.05wC0xq4sZiDTrxpOPKI8UMj1TLe/1ZXrOunv15HEgsKtXPyn4Q
              # In Nextcloud container, run:
              # nextcloud-occ user_oidc:provider Authelia --clientid="qNSntqAqO2MnumAAJzlvuiKkxYoyy5ExccOBocd6.bKS_C5oHGpi620A.pO7vh-CiLBQeagH" --clientsecret="boq0fc_mb4e~ht5zmA5iF7Qiq33saCiqE-OOTV2v4SdQnuiXk08xSr42p96hHcCuGDjyNooO" --discoveryuri="https://auth.moritzwm.de/.well-known/openid-configuration"
              client_id = "qNSntqAqO2MnumAAJzlvuiKkxYoyy5ExccOBocd6.bKS_C5oHGpi620A.pO7vh-CiLBQeagH";
              client_name = "Nextcloud";
              client_secret = "$pbkdf2-sha512$310000$6/TDVR1IzGQfrtE6yNCFvA$OiN8pG3.q3/TAdTQ8rJMD9KRDJ1DJIfqlw.05wC0xq4sZiDTrxpOPKI8UMj1TLe/1ZXrOunv15HEgsKtXPyn4Q";
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

      # Generate secrets and users file if they don't exist
      systemd.services.authelia-init = {
        wantedBy = [ "multi-user.target" ];
        before = [ "authelia-main.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          SECRETS_DIR="/var/lib/authelia-main"
          mkdir -p "$SECRETS_DIR"

          generate_secret() {
            if [ ! -f "$SECRETS_DIR/$1" ]; then
              ${pkgs.openssl}/bin/openssl rand -hex 32 > "$SECRETS_DIR/$1"
              chmod 600 "$SECRETS_DIR/$1"
              echo "Generated $1"
            fi
          }

          generate_secret "jwt_secret"
          generate_secret "session_secret"
          generate_secret "storage_encryption_key"
          generate_secret "oidc_hmac_secret"

          # Generate OIDC JWKS RSA key if it doesn't exist
          if [ ! -f "$SECRETS_DIR/jwks_private.pem" ]; then
            ${pkgs.authelia}/bin/authelia  crypto pair rsa generate --file.public-key "$SECRETS_DIR/jwks_public.pem" --file.private-key "$SECRETS_DIR/jwks_private.pem"
            chmod 600 "$SECRETS_DIR/jwks_public.pem"
            chmod 600 "$SECRETS_DIR/jwks_private.pem"
            echo "Generated OIDC JWKS RSA keypair"
          fi

          # Create users file if it doesn't exist
          if [ ! -f "$SECRETS_DIR/users.yml" ]; then
            cat > "$SECRETS_DIR/users.yml" << 'USERS'
          users:
            moritz:
              displayname: "Moritz"
              # Generate this hash with: nix-shell -p authelia --run "authelia crypto hash generate argon2 --password 'yourpassword'"
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
