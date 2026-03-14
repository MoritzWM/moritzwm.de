{ config, pkgs, lib, ... }:
let
  preConsumeScript = pkgs.writeScript "paperless-pre-consume" (builtins.readFile ./pre_consume.py);

  paperlessSecrets = [
    "paperless/admin_pass"
    "paperless/oidc_client_id"
    "paperless/oidc_client_secret"
    "paperless/secret_key"
    "paperless/pdf_passwords"
  ];
in
{
  environment.etc."traefik/dynamic/paperless.yml".text = ''
    http:
      routers:
        paperless-http:
          rule: "Host(`paperless.moritzwm.de`)"
          service: paperless
          entryPoints:
            - web
          middlewares:
            - https-redirect

        paperless-https:
          rule: "Host(`paperless.moritzwm.de`)"
          service: paperless
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt

      services:
        paperless:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:28981"
            passHostHeader: true
  '';
  sops = {
      secrets = lib.genAttrs paperlessSecrets (name: {
        owner = "root";
        group = "root";
        mode = "0400";
      });
      templates."paperless.env".content = ''
        PAPERLESS_ADMIN_PASSWORD=${config.sops.placeholder."paperless/admin_pass"}
        PAPERLESS_SECRET_KEY=${config.sops.placeholder."paperless/secret_key"}
        PAPERLESS_PDF_PASSWORDS=${config.sops.placeholder."paperless/pdf_passwords"}
        PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"${config.sops.placeholder."paperless/oidc_client_id"}","secret":"${config.sops.placeholder."paperless/oidc_client_secret"}","settings":{"server_url":"https://auth.moritzwm.de/.well-known/openid-configuration","token_auth_method":"client_secret_basic"}}]}}
  '';
  };

  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Create a named podman network so containers can resolve each other by name
  systemd.services.podman-network-paperless = {
    wantedBy = [
      "podman-paperless-broker.service"
      "podman-paperless-db.service"
      "podman-paperless-webserver.service"
    ];
    before = [
      "podman-paperless-broker.service"
      "podman-paperless-db.service"
      "podman-paperless-webserver.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.podman}/bin/podman network exists paperless || \
        ${pkgs.podman}/bin/podman network create paperless
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/paperless/consume 0755 root root -"
    "d /var/lib/paperless/export 0755 root root -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      paperless-broker = {
        image = "docker.io/library/redis:8";
        volumes = [ "paperless-redisdata:/data" ];
        extraOptions = [ "--network=paperless" ];
      };

      paperless-db = {
        image = "docker.io/library/postgres:18";
        volumes = [ "paperless-pgdata:/var/lib/postgresql" ];
        environment = {
          POSTGRES_DB = "paperless";
          POSTGRES_USER = "paperless";
          POSTGRES_PASSWORD = "paperless";
        };
        extraOptions = [ "--network=paperless" ];
      };

      paperless-webserver = {
        image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
        ports = [ "127.0.0.1:28981:8000" ];
        volumes = [
          "paperless-data:/usr/src/paperless/data"
          "/mnt/storagebox_paperless:/usr/src/paperless/media"
          "/var/lib/paperless/consume:/usr/src/paperless/consume"
          "/var/lib/paperless/export:/usr/src/paperless/export"
          "${preConsumeScript}:/usr/src/paperless/scripts/pre-consume.py:ro"
        ];
        environment = {
          USERMAP_UID = "999";
          USERMAP_GID = "999";
          PAPERLESS_REDIS = "redis://paperless-broker:6379";
          PAPERLESS_DBHOST = "paperless-db";
          PAPERLESS_DBNAME = "paperless";
          PAPERLESS_DBUSER = "paperless";
          PAPERLESS_DBPASS = "paperless";
          PAPERLESS_URL = "https://paperless.moritzwm.de";
          PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
          PAPERLESS_SOCIAL_AUTO_SIGNUP = "true";
          PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
          PAPERLESS_PRE_CONSUME_SCRIPT = "/usr/src/paperless/scripts/pre-consume.py";
          PAPERLESS_ADMIN_USER = "admin";
          PAPERLESS_ALLOWED_HOSTS = "paperless.moritzwm.de";
        };
        environmentFiles = [ config.sops.templates."paperless.env".path ];
        dependsOn = [ "paperless-broker" "paperless-db" ];
        extraOptions = [ "--network=paperless" ];
      };
    };
  };
}
