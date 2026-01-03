{ config, pkgs, lib, sops-nix, ... }:
{
  # Traefik dynamic configuration for Mealie
  environment.etc."traefik/dynamic/tandoor.yml".text = ''
    http:
      routers:
        tandoor-http:
          rule: "Host(`rezepte.moritzwm.de`)"
          service: tandoor
          entryPoints:
            - web
          middlewares:
            - https-redirect

        tandoor-https:
          rule: "Host(`rezepte.moritzwm.de`)"
          service: tandoor
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt
          middlewares:
            - authelia

      services:
        tandoor:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:9000"
            passHostHeader: true
  '';

  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman.defaultNetwork.settings.dns_enabled = true;
  virtualisation.oci-containers.containers.tandoor = {
    image = "vabene1111/recipes";
    autoStart = true;
    ports = [ "9000:80" ];
    dependsOn = [ "tandoor-db" ];
    volumes = [
      "/var/lib/tandoor/staticfiles:/opt/recipes/staticfiles"
      "/var/lib/tandoor/mediafiles:/opt/recipes/mediafiles"
    ];

    environment = {
      ALLOWED_HOSTS = "rezepte.moritzwm.de";
      DB_HOST = "tandoor-db";
      DB_NAME = "recipes";
      DB_USER = "recipes";
      DB_PORT = "5432";
    };

    environmentFiles = [
      config.sops.templates."tandoor_secrets".path
    ];
  };

  virtualisation.oci-containers.containers.tandoor-db = {
    image = "postgres:16-alpine";
    autoStart = true;
    volumes = [
      "${config.sops.secrets."tandoor/db_password".path}:/run/postgres_pass"
    ];
    environment = {
      POSTGRES_DB = "recipes";
      POSTGRES_USER = "recipes";
      POSTGRES_PASSWORD_FILE = "/run/postgres_pass";
    };
  };

  # Setup credentials file as environment file
  sops.secrets."tandoor/django_secret" = {};
  sops.secrets."tandoor/oidc_client_id" = {};
  sops.secrets."tandoor/oidc_client_secret" = {};
  sops.secrets."tandoor/db_password" = {};
  sops.templates."tandoor_secrets".content  = ''
    SOCIAL_PROVIDERS=allauth.socialaccount.providers.openid_connect
    SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"${config.sops.placeholder."tandoor/oidc_client_id"}","secret":"${config.sops.placeholder."tandoor/oidc_client_secret"}","settings":{"server_url":"https://auth.moritzwm.de/.well-known/openid-configuration","token_auth_method":"client_secret_basic"}}]}}
    POSTGRES_PASSWORD=${config.sops.placeholder."tandoor/db_password"}
    SECRET_KEY=${config.sops.placeholder."tandoor/django_secret"}
  '';
}
