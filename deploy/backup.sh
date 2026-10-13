#!/usr/bin/env bash
# Nightly logical backup. Install in the postgres user's crontab:
#   15 2 * * * /opt/croploss/backup.sh
# Then copy the dump OFF the instance (e.g. Nectar object storage via rclone).
set -euo pipefail
DEST=/var/backups/croploss
mkdir -p "$DEST"
pg_dump -Fc croploss > "$DEST/croploss_$(date +%F).dump"
find "$DEST" -name 'croploss_*.dump' -mtime +14 -delete
