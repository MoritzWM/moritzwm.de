{ config, pkgs, ... }:
{
  sops.secrets."borg/repo_pass" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.templates."borg_env".content = ''
    BORG_REPO=ssh://root@192.168.178.75/hub/backup
    BORG_PASSPHRASE=${config.sops.placeholder."borg/repo_pass"}
  '';

  systemd.services.borgbackup = {
    description = "Borg backup";
    path = [ pkgs.bash pkgs.borgbackup pkgs.openssh pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.templates."borg_env".path;
      ExecStart = "${pkgs.bash}/bin/bash ${./backup.sh}";
    };
  };

  systemd.timers.borgbackup = {
    description = "Run borg backup every day at 03:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };
  };
}
