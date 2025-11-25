{ config, pkgs, lib, ... }:
{
  # Authelia configuration directory
  environment.etc."authelia/configuration.yml".text = ''
    # Authelia configuration
    theme: dark

    server:
      address: tcp://0.0.0.0:9091/

    log:
      level: info
      format: text

    totp:
      issuer: moritzwm.de
      period: 30
      skew: 1

    authentication_backend:
      file:
        path: /config/users.yml
        password:
          algorithm: argon2id
          iterations: 3
          memory: 65536
          parallelism: 4
          key_length: 32
          salt_length: 16

    access_control:
      default_policy: deny
      rules:
        # Allow Nextcloud to be accessed without Authelia (it has its own auth)
        - domain: hetzner.moritzwm.de
          policy: bypass
        # Authelia itself should be accessible
        - domain: auth.moritzwm.de
          policy: bypass
        # Protected services require two_factor
        - domain: "*.moritzwm.de"
          policy: two_factor

    session:
      name: authelia_session
      domain: moritzwm.de
      same_site: lax
      expiration: 1h
      inactivity: 5m
      remember_me: 1M
      cookies:
        - domain: moritzwm.de
          authelia_url: https://auth.moritzwm.de

    regulation:
      max_retries: 3
      find_time: 2m
      ban_time: 5m

    storage:
      local:
        path: /data/db.sqlite3

    notifier:
      filesystem:
        filename: /data/notification.txt
  '';

  # Users database template - you should generate proper password hashes
  # Use: docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'yourpassword'
  environment.etc."authelia/users.yml".text = ''
    users:
      moritz:
        disabled: false
        displayname: "Moritz"
        # Generate this hash with: docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'yourpassword'
        password: "$argon2id$v=19$m=65536,t=3,p=4$CHANGE_THIS_PASSWORD_HASH"
        email: mail@moritzwm.de
        groups:
          - admins
          - users
  '';

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
              - url: "http://127.0.0.1:9091"

      middlewares:
        authelia:
          forwardAuth:
            address: "http://127.0.0.1:9091/api/authz/forward-auth"
            trustForwardHeader: true
            authResponseHeaders:
              - Remote-User
              - Remote-Groups
              - Remote-Name
              - Remote-Email
  '';

  # Create required directories
  systemd.tmpfiles.rules = [
    "d /var/lib/authelia 0750 root root -"
    "d /var/lib/authelia/data 0750 root root -"
  ];

  # Generate secrets if they don't exist
  systemd.services.authelia-secrets = {
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-authelia.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      SECRETS_DIR="/var/lib/authelia"

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
    '';
  };

  # Enable podman for OCI containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # Authelia OCI container
  virtualisation.oci-containers = {
    backend = "podman";
    containers.authelia = {
      image = "docker.io/authelia/authelia:4.38";
      autoStart = true;
      ports = [ "127.0.0.1:9091:9091" ];
      volumes = [
        "/etc/authelia/configuration.yml:/config/configuration.yml:ro"
        "/etc/authelia/users.yml:/config/users.yml:ro"
        "/var/lib/authelia/data:/data"
        "/var/lib/authelia/jwt_secret:/secrets/jwt_secret:ro"
        "/var/lib/authelia/session_secret:/secrets/session_secret:ro"
        "/var/lib/authelia/storage_encryption_key:/secrets/storage_encryption_key:ro"
      ];
      environment = {
        TZ = "Europe/Berlin";
        AUTHELIA_JWT_SECRET_FILE = "/secrets/jwt_secret";
        AUTHELIA_SESSION_SECRET_FILE = "/secrets/session_secret";
        AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE = "/secrets/storage_encryption_key";
      };
      extraOptions = [
        "--network=host"
      ];
    };
  };
}
