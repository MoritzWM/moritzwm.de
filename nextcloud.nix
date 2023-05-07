{ config, pkgs, ... }:
{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "mail@moritzwm.de";
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nginx = {
    enable = true;
    virtualHosts = {
      "cloud.${config.networking.fqdn}" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "cloud.moritzwm.de" ];
        locations."/" = {
          root = "/var/lib/nextcloud/";
        };
      };
    };
  };

  # https://nixos.wiki/wiki/Nextcloud
  # Update by:
  # nextcloud-occ maintenance:mode --on
  # Increment package version number by one (not more!)
  # nixos-rebuild switch
  # nextcloud-occ maintenance:mode --off
  services.nextcloud = {
    enable = true;
    hostName = "cloud.${config.networking.fqdn}";
    package = pkgs.nextcloud26;
    enableBrokenCiphersForSSE = false;
    config = {
      dbtype = "pgsql";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql"; 
      dbname = "nextcloud";
      adminpassFile = "/etc/nixos/nextcloud_pass.secret";
      adminuser = "moritz_admin";
      extraTrustedDomains = [ "cloud.moritzwm.de" ];
      defaultPhoneRegion = "DE";
      overwriteProtocol = "https";
    };
    extraOptions = {
      preview_max_memory = 4096;
      preview_max_filesize_image = 256;
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_13;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
     { name = "nextcloud";
       ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
     }
    ];
  };

  # ensure that postgres is running *before* running the setup
  systemd.services."nextcloud-setup" = {
    requires = ["postgresql.service"];
    after = ["postgresql.service"];
  };

  # Nextcloud preview generator
  # https://apps.nextcloud.com/apps/previewgenerator
  systemd.services."nextcloud-generate-preview" = {
    description = "Nextcloud Preview Generator";
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      ExecStart = "/run/current-system/sw/bin/nextcloud-occ preview:pre-generate";
    };
    wantedBy = [ "basic.target" ];
  };

  systemd.timers."nextcloud-generate-preview" = {
    enable = true;
    unitConfig = {
      Description = "Run Nextcloud Preview Generator daily at 02:00";
    };
    timerConfig = {
      OnCalendar = "*-*-* 2:00:00";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

  # Mount the data dir (it's an NFS share)
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
  fileSystems."${config.services.nextcloud.datadir}/data" = {
    device = "46.38.248.211:/voln481806a1";
    fsType = "nfs";
    options = [
      "auto"
    ];
  };

  # Allow pg_dump for passwordless backup
  security.sudo = {
    enable = true;
    extraRules = [{
      commands = [{
	command = "${pkgs.postgresql_13}/bin/pg_dump";
	options = [ "NOPASSWD" ];
      }{
        command = "${pkgs.nextcloud26}/bin/nextcloud-occ";
	options = [ "NOPASSWD" ];
      }{
        command = "${pkgs.rsync}/bin/rsync";
	options = [ "NOPASSWD" ];
      }];
      runAs = "nextcloud";
      groups = [ "wheel" ];
    }];
  };
}
