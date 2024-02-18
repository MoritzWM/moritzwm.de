{ config, pkgs, ... }:
{
  # https://nixos.org/manual/nixos/stable/index.html#module-services-postgres-upgrading
  environment.systemPackages = [
    (let
      # The postgresql version to upgrade to
      newPostgres = pkgs.postgresql_15.withPackages (pp: [
        # packages
      ]);
    in pkgs.writeScriptBin "upgrade-pg-cluster" ''
      set -eux
      nextcloud-occ maintenance:mode --on
      systemctl stop phpfpm-nextcloud
      systemctl stop vaultwarden
      systemctl stop postgresql

      export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"

      export NEWBIN="${newPostgres}/bin"

      export OLDDATA="${config.services.postgresql.dataDir}"
      export OLDBIN="${config.services.postgresql.package}/bin"

      install -d -m 0700 -o postgres -g postgres "$NEWDATA"
      cd "$NEWDATA"
      sudo -u postgres $NEWBIN/initdb -D "$NEWDATA"

      sudo -u postgres $NEWBIN/pg_upgrade \
        --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
        --old-bindir $OLDBIN --new-bindir $NEWBIN \
        "$@"
    '')
  ];
}
