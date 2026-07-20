{ config, pkgs, lib, ... }:
let
  # https://github.com/mealie-recipes/mealie/releases
  mealieVersion = "v3.20.1";
  hostPort = 9925;
in
{
  sops.secrets."mealie/oidc_client_id" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."mealie/oidc_client_secret" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.templates."mealie_oidc_env".content = ''
    OIDC_CLIENT_ID=${config.sops.placeholder."mealie/oidc_client_id"}
    OIDC_CLIENT_SECRET=${config.sops.placeholder."mealie/oidc_client_secret"}
  '';

  environment.etc."traefik/dynamic/mealie.yml".text = ''
    http:
      routers:
        mealie-http:
          rule: "Host(`rezepte.moritzwm.de`)"
          service: mealie
          entryPoints:
            - web
          middlewares:
            - https-redirect

        mealie-https:
          rule: "Host(`rezepte.moritzwm.de`)"
          service: mealie
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt

      services:
        mealie:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:${toString hostPort}"
            passHostHeader: true
  '';

  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      mealie = {
        image = "ghcr.io/mealie-recipes/mealie:${mealieVersion}";
        autoStart = true;
        ports = [ "127.0.0.1:${toString hostPort}:9000" ];
        volumes = [ "mealie-data:/app/data" ];
        environment = {
          TZ = "Europe/Berlin";
          BASE_URL = "https://rezepte.moritzwm.de";
          DB_ENGINE = "sqlite";
          ALLOW_SIGNUP = "false";

          OIDC_AUTH_ENABLED = "true";
          OIDC_CONFIGURATION_URL = "https://auth.moritzwm.de/.well-known/openid-configuration";
          OIDC_PROVIDER_NAME = "Authelia";
          OIDC_SIGNUP_ENABLED = "true";
          OIDC_REMEMBER_ME = "true";
          OIDC_AUTO_REDIRECT = "true";
          OIDC_GROUPS_CLAIM = "groups";
          OIDC_USER_GROUP = "users";
          OIDC_ADMIN_GROUP = "admins";
        };
        environmentFiles = [ config.sops.templates."mealie_oidc_env".path ];
      };
    };
  };
}
