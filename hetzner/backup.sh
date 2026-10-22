#!/usr/bin/env bash
# Copied from the borg backup quickstart guide:
# https://borgbackup.readthedocs.io/en/stable/quickstart.html

info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM
borg_create() {
    borg create --verbose --list --stats --compression zstd --show-rc $@
}

info "Starting backup"

# Paperless
podman exec paperless-webserver\
	document_exporter --delete ../export

borg_create\
	::'{hostname}-paperless-{now}'\
	/var/lib/paperless/export

# Immich
borg_create\
	::'{hostname}-immich-{now}'\
	/mnt/storagebox_immich/{backups,library,profile,upload}



backup_exit=$?

info "Pruning repository"

borg prune                          \
    --list                          \
    --glob-archives '{hostname}-*'  \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6

prune_exit=$?

# actually free repo disk space by compacting segments

info "Compacting repository"

borg compact

compact_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
global_exit=$(( compact_exit > global_exit ? compact_exit : global_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
else
    info "Backup, Prune, and/or Compact finished with errors"
fi

exit ${global_exit}
