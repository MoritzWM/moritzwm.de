{ config, pkgs, lib, ... }:
let
  # Pin the Immich release. Bump this to upgrade (see https://github.com/immich-app/immich/releases).
  immichVersion = "v3.0.1";

  # PostgreSQL image. We use the PG17 VectorChord variant (NOT the guide's default PG14
  # image) because the previous native NixOS install ran PostgreSQL 17 — this keeps the
  # major version identical so a logical pg_dump/restore is a clean same-version restore
  # instead of an unsupported downgrade. Immich supports PG14-17.
  postgresImage = "ghcr.io/immich-app/postgres:17-vectorchord0.4.3";
  redisImage = "docker.io/valkey/valkey:9.1.0";

  # Media (photos/videos/thumbs/encoded-video/profile). Same Storage Box path the native
  # install used as `mediaLocation`, mounted to /data inside the container.
  mediaLocation = "/mnt/storagebox_immich";

  # Database data dir. MUST be on local disk — network shares are unsupported for Postgres.
  dbDataLocation = "/var/lib/immich-postgres";

  dbUser = "immich"; # matches the role that owns the objects in the dump
  dbName = "immich";
in
{
  # sops secret holding the internal Postgres password (add `immich/db_password` to
  # hetzner/secrets.yaml). Rendered into an env file consumed by both containers.
  sops.secrets."immich/db_password" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.templates."immich_db_env".content = ''
    DB_PASSWORD=${config.sops.placeholder."immich/db_password"}
    POSTGRES_PASSWORD=${config.sops.placeholder."immich/db_password"}
  '';

  # Traefik now targets the Docker-published port on the host loopback.
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
              - url: "http://127.0.0.1:2283"
            passHostHeader: true
  '';

  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
    # oci-containers pulls new images on tag bumps but never removes the old ones;
    # prune unused images/containers weekly so /var/lib/containers doesn't grow forever.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Local storage for the Postgres data directory.
  systemd.tmpfiles.rules = [
    "d ${dbDataLocation} 0700 root root - -"
  ];

  # The media lives on the CIFS Storage Box; don't start the server until it's mounted.
  systemd.services.podman-immich-server.unitConfig.RequiresMountsFor = "/mnt/storagebox_immich";

  # Named podman network so the containers can resolve each other by name.
  systemd.services.podman-network-immich = {
    wantedBy = [
      "podman-immich-server.service"
      "podman-immich-machine-learning.service"
      "podman-immich-redis.service"
      "podman-immich-postgres.service"
    ];
    before = [
      "podman-immich-server.service"
      "podman-immich-machine-learning.service"
      "podman-immich-redis.service"
      "podman-immich-postgres.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.podman}/bin/podman network exists immich || \
        ${pkgs.podman}/bin/podman network create immich
    '';
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      immich-server = {
        image = "ghcr.io/immich-app/immich-server:${immichVersion}";
        autoStart = true;
        # Publish only on loopback; Traefik terminates TLS and proxies here.
        ports = [ "127.0.0.1:2283:2283" ];
        volumes = [
          "${mediaLocation}:/data"
          "/etc/localtime:/etc/localtime:ro"
        ];
        environment = {
          DB_HOSTNAME = "immich-postgres";
          DB_USERNAME = dbUser;
          DB_DATABASE_NAME = dbName;
          DB_VECTOR_EXTENSION = "vectorchord";
          REDIS_HOSTNAME = "immich-redis";
          TZ = "Europe/Berlin";
          IMMICH_LOG_LEVEL = "log";
        };
        environmentFiles = [ config.sops.templates."immich_db_env".path ];
        dependsOn = [ "immich-postgres" "immich-redis" ];
        extraOptions = [ "--network=immich" ];
      };

      immich-machine-learning = {
        image = "ghcr.io/immich-app/immich-machine-learning:${immichVersion}";
        autoStart = true;
        volumes = [ "immich-model-cache:/cache" ];
        environment = {
          TZ = "Europe/Berlin";
        };
        extraOptions = [ "--network=immich" ];
      };

      immich-redis = {
        image = redisImage;
        autoStart = true;
        extraOptions = [ "--network=immich" ];
      };

      immich-postgres = {
        image = postgresImage;
        autoStart = true;
        environment = {
          POSTGRES_USER = dbUser;
          POSTGRES_DB = dbName;
          POSTGRES_INITDB_ARGS = "--data-checksums";
        };
        environmentFiles = [ config.sops.templates."immich_db_env".path ];
        volumes = [ "${dbDataLocation}:/var/lib/postgresql/data" ];
        extraOptions = [
          "--network=immich"
          "--shm-size=128m"
        ];
      };
    };
  };
}
