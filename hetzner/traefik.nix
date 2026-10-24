{ config, pkgs, lib, ... }:
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  sops.secrets."traefik/hetzner_dns_token" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.templates."traefik_hetzner_env".content = ''
    HETZNER_API_KEY=${config.sops.placeholder."traefik/hetzner_dns_token"}
  '';

  systemd.services.traefik.serviceConfig.EnvironmentFile = config.sops.templates."traefik_hetzner_env".path;

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
          http.tls = {
            certResolver = "letsencrypt";
            domains = [{
              main = "moritzwm.de";
              sans = [ "*.moritzwm.de" ];
            }];
          };
          transport.respondingTimeouts.readTimeout = "0s";
        };
      };

      certificatesResolvers.letsencrypt.acme = {
        email = "mail@moritzwm.de";
        storage = "/var/lib/traefik/acme.json";
        dnsChallenge.provider = "hetzner";
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
