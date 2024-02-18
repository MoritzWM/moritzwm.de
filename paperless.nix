{ config, pkgs, ... }:
{
  services.paperless = {
    enable = true;
    port = 58080;
    passwordFile = "/etc/nixos/paperless_pass.secret";
    extraConfig.PAPERLESS_OCR_LANGUAGE = "deu";
  };
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "25m";
    virtualHosts = {
      "paperless.${config.networking.fqdn}" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "paperless.moritzwm.de" ];
        locations."/" = {
	  proxyPass = "http://localhost:58080/";
        };
      };
    };
  };

  # Allow stopping the service
  security.sudo = {
    enable = true;
    extraRules = [{
      commands = [{
	command = "${pkgs.systemd}/bin/systemctl stop paperless";
	options = [ "NOPASSWD" ];
      }{
	command = "${pkgs.systemd}/bin/systemctl start paperless";
	options = [ "NOPASSWD" ];
      }];
      groups = [ "wheel" ];
    }];
  };
}
