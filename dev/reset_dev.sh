#!/usr/bin/env bash
# Tear down the local dev environment so the README can be followed again
# from step 0.
# DESTROYS the dev Postgres volume (all data), the postgres:16 image pulled for
# it, and your local .Renviron.
# Usage: ./dev/reset_dev.sh        (asks for confirmation)
#        ./dev/reset_dev.sh --yes  (no prompt)
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Delete the dev database volume, its Docker image and .Renviron? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# --rmi all removes the images this compose file uses (postgres:16), so the
# next `up` pulls it fresh. Docker skips an image another container still uses.
docker compose -f dev/docker-compose.yml down -v --rmi all
rm -f .Renviron
echo "Reset complete. Follow the README again from step 1 (step 0 only if r-lib/ was removed)."
