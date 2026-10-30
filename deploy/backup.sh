#!/usr/bin/env bash
# Logical backup of the production database, run from the host.
# Usage: ./deploy/backup.sh            (writes to /var/backups/croploss)
# Nightly, via cron (crontab -e):
#   15 2 * * * /opt/croploss/deploy/backup.sh
# Then copy the dumps OFF this server (e.g. object storage via rclone).
# Restore instructions: docs/DEPLOY.md
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${BACKUP_DIR:-/var/backups/croploss}"
mkdir -p "$DEST"
docker compose -f deploy/docker-compose.yml exec -T db \
  pg_dump -U croploss_owner -Fc croploss > "$DEST/croploss_$(date +%F).dump"
find "$DEST" -name 'croploss_*.dump' -mtime +14 -delete
