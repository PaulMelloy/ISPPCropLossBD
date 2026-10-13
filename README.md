# croplossdb

Prototype Shiny application for the ISPP Crop Loss Subcommittee database.
PostgreSQL back end, ORCID sign-in, and a full audit trail of every change.

**Start here:** [`docs/BUILD_PROTOCOL.md`](docs/BUILD_PROTOCOL.md)

Quick start (local, development login):

```bash
docker compose -f dev/docker-compose.yml up -d
OWNER_URL=postgres://croploss_owner:owner_dev_password@localhost:5432/croploss \
APP_PASSWORD=app_dev_password ./dev/setup_db.sh
cp dev/Renviron.example .Renviron   # then uncomment CROPLOSS_DEV_AUTH
```

```r
source("dev/run_dev.R")
```
