{ config, pkgs, lib, sops-nix, ... }:
let
  preConsumeScript = pkgs.writeScript "paperless-pre-consume" (builtins.readFile ./pre_consume.py);

  paperlessSecrets = [
    "paperless/admin_pass"
    "paperless/oidc_client_id"
    "paperless/oidc_client_secret"
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
              - url: "http://10.233.4.2:28981"
            passHostHeader: true
  '';

  # NixOS container for Paperless-ngx
  containers.paperless = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.4.1";
    localAddress = "10.233.4.2";

    # Bind mount the age key so sops-nix can decrypt secrets inside the container
    bindMounts = {
      "/var/lib/sops-nix/keys.txt" = {
        hostPath = "/var/lib/sops-nix/keys.txt";
        isReadOnly = true;
      };
      "/var/lib/paperless/media" = {
        hostPath = "/mnt/storagebox_paperless";
        isReadOnly = false;
      };
    };

    config = { config, pkgs, lib, ... }: {
      imports = [
        sops-nix.nixosModules.sops
      ];

      # Configure sops-nix inside the container
      sops = {
        defaultSopsFile = ./secrets.yaml;
        age.keyFile = "/var/lib/sops-nix/keys.txt";

        secrets = lib.genAttrs paperlessSecrets (name: {
          owner = "paperless";
          group = "paperless";
          mode = "0400";
        });
      };

      system.stateVersion = "25.11";
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 28981 ];
      };

      services.paperless = {
        enable = true;
        address = "0.0.0.0";
        port = 28981;
        passwordFile = config.sops.secrets."paperless/admin_pass".path;
        environmentFile = "/run/paperless-oidc.env";
        database.createLocally = true;

        settings = {
          PAPERLESS_URL = "https://paperless.moritzwm.de";
          PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
          PAPERLESS_SOCIAL_AUTO_SIGNUP = "true";
          PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
          PAPERLESS_PRE_CONSUME_SCRIPT = "${preConsumeScript}";
        };
      };

      services.postgresqlBackup = {
        enable = true;
        databases = [ "paperless" ];
      };

      # Write OIDC env file from individual sops secrets at boot
      systemd.services.paperless-init-oidc-env = {
        wantedBy = [ "paperless-scheduler.service" "paperless-consumer.service" "paperless-web.service" ];
        before = [ "paperless-scheduler.service" "paperless-consumer.service" "paperless-web.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          client_id=$(cat ${config.sops.secrets."paperless/oidc_client_id".path})
          client_secret=$(cat ${config.sops.secrets."paperless/oidc_client_secret".path})
          printf 'PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"%s","secret":"%s","settings":{"server_url":"https://auth.moritzwm.de/.well-known/openid-configuration","token_auth_method":"client_secret_basic"}}]}}\n' \
            "$client_id" "$client_secret" > /run/paperless-oidc.env
          chown paperless:paperless /run/paperless-oidc.env
          chmod 400 /run/paperless-oidc.env
        '';
      };
    };
  };
}
