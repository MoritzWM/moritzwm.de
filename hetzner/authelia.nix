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
            password = {
              algorithm = "argon2id";
              iterations = 3;
              memory = 65536;
              parallelism = 4;
              key_length = 32;
              salt_length = 16;
            };
          };

          access_control = {
            default_policy = "deny";
            rules = [
              # Allow Nextcloud to be accessed without Authelia (it has its own auth)
              { domain = "hetzner.moritzwm.de"; policy = "bypass"; }
              # Authelia itself should be accessible
              { domain = "auth.moritzwm.de"; policy = "bypass"; }
              # Protected services require two_factor
              { domain = "*.moritzwm.de"; policy = "two_factor"; }
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

          # Create users file if it doesn't exist
          if [ ! -f "$SECRETS_DIR/users.yml" ]; then
            cat > "$SECRETS_DIR/users.yml" << 'USERS'
          users:
            moritz:
              disabled: false
              displayname: "Moritz"
              # Generate this hash with: nix-shell -p authelia --run "authelia crypto hash generate argon2 --password 'yourpassword'"
              password: "$argon2id$v=19$m=65536,t=3,p=4$CHANGE_THIS_PASSWORD_HASH"
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
