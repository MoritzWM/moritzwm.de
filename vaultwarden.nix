{ config, pkgs, ... }:
{
  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = /var/vaultwarden.secret;
    config = {
      webVaultFolder = "${pkgs.vaultwarden-vault}/share/vaultwarden/vault";
      WEB_VAULT_ENABLED = true;
      WEBSOCKET_ENABLED = true;
      SIGNUPS_VERIFY = true;
      DISABLE_ADMIN_TOKEN = false;
      SMTP_HOST = "posteo.de";
      SMTP_FROM = "cloud.twiessalla@posteo.de";
      SMTP_FROM_NAME = "cloud.twiessalla_vaultwarden";
      SMTP_PORT = 587;
      SMTP_SECURITY = "starttls";
      SMTP_USERNAME = (import /var/vaultwarden_email.secret).SMTP_USERNAME;
      SMTP_PASSWORD = (import /var/vaultwarden_email.secret).SMTP_PASSWORD;
      SMTP_TIMEOUT = 15;
      LOG_FILE = "/var/log/vaultwarden";
    };
  };
  security.acme.defaults.email = "tristan.wiessalla@posteo.de";
  security.acme.acceptTerms = true;

  services.nginx = {
    enable = true;
    
    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "vault.twiessalla.de" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "vault.v2202302194336219745.megasrv.de" ];
        locations."/" = {
          proxyPass = "https://127.0.0.1:8800";
          proxyWebsockets = true;
        };
        locations."/notifications/hub" = {
          proxyPass = "https://127.0.0.1:3012";
          proxyWebsockets = true;
        };
        locations."/notifications/hub/negotiate" = {
          proxyPass = "https://127.0.0.1:8800";
          proxyWebsockets = true;
        };

      };
    };
  };
}
