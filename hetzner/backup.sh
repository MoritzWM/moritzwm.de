#!/usr/bin/env bash
# Copied from the borg backup quickstart guide:
# https://borgbackup.readthedocs.io/en/stable/quickstart.html

info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM
borg_create() {
    borg create --verbose --list --stats --compression zstd --show-rc $@
}
borg_prune() {
    borg prune \
        --list \
        --glob-archives "$1" \
        --show-rc \
        --keep-daily    7 \
        --keep-weekly   4 \
        --keep-monthly  6
}


backup_paperless() (
    set -e
    podman exec paperless-webserver\
    	document_exporter --delete ../export
    borg_create\
    	::'{hostname}-paperless-{now}'\
    	/var/lib/paperless/export
     borg_prune '{hostname}-paperless-*'
)

backup_immich() (
    set -e
    borg_create\
    	::'{hostname}-immich-{now}'\
    	/mnt/storagebox_immich/{backups,library,profile,upload}
     borg_prune '{hostname}-immich-*'
)

info "Starting backup"

backup_paperless
paperless_exit=$?
backup_immich
immich_exit=$?
borg compact
compact_exit=$?

# use highest exit code as global exit code
global_exit=$(( paperless_exit > immich_exit ? paperless_exit : immich_exit ))
global_exit=$(( compact_exit > global_exit ? compact_exit : global_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
else
    info "Script finished with warnings/errors: paperless=${paperless_exit}; immich=${immich_exit}; compact=${compact_exit}"
fi

exit ${global_exit}
