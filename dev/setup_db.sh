#!/usr/bin/env bash
# Create schema, audit trail, app role and seed data.
# Usage: OWNER_URL=postgres://croploss_owner:owner_dev_password@localhost:5432/croploss \
#        APP_PASSWORD=app_dev_password ./dev/setup_db.sh
set -euo pipefail
: "${OWNER_URL:?Set OWNER_URL to a superuser/owner connection string}"
: "${APP_PASSWORD:?Set APP_PASSWORD for the croploss_app role}"
SQL_DIR="$(cd "$(dirname "$0")/../inst/sql" && pwd)"

psql "$OWNER_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/001_schema.sql"
psql "$OWNER_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/002_audit.sql"
psql "$OWNER_URL" -v ON_ERROR_STOP=1 -v app_password="$APP_PASSWORD" -f "$SQL_DIR/003_roles.sql"
psql "$OWNER_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/004_seed.sql"
echo "Database ready."
