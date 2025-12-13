{ config, pkgs, lib, ... }:
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.nat = {
    enable = true;
    internalInterfaces = ["ve-+"];
    externalInterface = "enp1s0";
  };

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          # http.redirections.entrypoint = {
            # to = "websecure";
            # scheme = "https";
          # };
        };
        websecure = {
          address = ":443";
          http.tls.certResolver = "letsencrypt";
        };
      };

      certificatesResolvers.letsencrypt.acme = {
        email = "mail@moritzwm.de";
        storage = "/var/lib/traefik/acme.json";
        httpChallenge.entryPoint = "web";
      };

      api = {
        dashboard = true;
        insecure = false;
      };

      providers.file = {
        directory = "/etc/traefik/dynamic";
        watch = true;
      };
    };
  };
  # Ensure Traefik data directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/traefik 0750 traefik traefik -"
  ];
}