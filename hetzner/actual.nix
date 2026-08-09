{ config, pkgs, lib, ... }:
let
  hostPort = 5006;
in
{
  sops.secrets."actual/oidc_client_id" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."actual/oidc_client_secret" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.templates."actual_oidc_env".content = ''
    ACTUAL_OPENID_CLIENT_ID=${config.sops.placeholder."actual/oidc_client_id"}
    ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder."actual/oidc_client_secret"}
  '';

  environment.etc."traefik/dynamic/actual.yml".text = ''
    http:
      routers:
        actual-http:
          rule: "Host(`kohle.moritzwm.de`)"
          service: actual
          entryPoints:
            - web
          middlewares:
            - https-redirect

        actual-https:
          rule: "Host(`kohle.moritzwm.de`)"
          service: actual
          entryPoints:
            - websecure
          tls:
            certResolver: letsencrypt

      services:
        actual:
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
      actual = {
        image = "docker.io/actualbudget/actual-server:latest";
        autoStart = true;
        ports = [ "127.0.0.1:${toString hostPort}:${toString hostPort}" ];
        volumes = [ "actual-data:/data" ];
        environment = {
          ACTUAL_LOGIN_METHOD = "openid";
          ACTUAL_OPENID_DISCOVERY_URL = "https://auth.moritzwm.de";
          ACTUAL_OPENID_SERVER_HOSTNAME = "https://kohle.moritzwm.de";
        };
        environmentFiles = [ config.sops.templates."actual_oidc_env".path ];
      };
    };
  };
}

