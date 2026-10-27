# croplossdb

Prototype Shiny application for the ISPP Crop Loss Subcommittee database.
PostgreSQL back end, ORCID sign-in, and a full audit trail of every change.

**Start here:** [`docs/BUILD_PROTOCOL.md`](docs/BUILD_PROTOCOL.md)

Quick start (local, development login):

### 0. Install dependencies (once)

```bash
./packages_dependancies.sh
```

This installs the system libraries (needs `sudo`; supports pacman, apt and dnf;
pass `--skip-system` to skip) and then installs the R packages into `./r-lib`
inside the repo rather than your global R library. `r-lib/` is git-ignored.
The R packages are read from `DESCRIPTION` (Imports and Suggests) plus
`pkgload`:

`bslib`, `DBI`, `DT`, `htmltools`, `httr2`, `jsonlite`, `openssl`, `pool`,
`RPostgres`, `shiny`, `testthat`, `pkgload`

System requirements: a C/C++/Fortran toolchain, R >= 4.1, libpq (with headers)
and `psql`, OpenSSL and libcurl (with headers), and Docker with Compose.

`dev/Renviron.example` sets `R_LIBS=r-lib`, so once copied to `.Renviron` (step
2) R finds these packages when started from the project root.

### 1. Start the database

```bash
docker compose -f dev/docker-compose.yml up -d
```

### 2. Create the schema and `.Renviron`

```bash
OWNER_URL=postgres://croploss_owner:owner_dev_password@localhost:5432/croploss \
APP_PASSWORD=app_dev_password ./dev/setup_db.sh
cp dev/Renviron.example .Renviron
```

### What you must edit in `.Renviron` (development)

If you used the commands above unchanged, **the only edit needed is
uncommenting `CROPLOSS_DEV_AUTH`** (delete the leading `# ` on that line).

`CROPLOSS_DEV_AUTH` is a development shortcut. When it is set, the app does not
show the ORCID login. It signs you in automatically as the ORCID iD you put in
that variable (format `0000-0000-0000-000X`), under the name "Development
User". If that iD is not yet in the `app_user` table it is created there on
first start with the default `contributor` role. The iD in the example file is
the project author's; you can leave it or replace it with any valid iD, for
example your own. Every record you enter and every audit entry is attributed
to that iD.

| Variable | Dev action | Notes |
|---|---|---|
| `CROPLOSS_DEV_AUTH` | **Uncomment** | Skips ORCID sign-in. Development only, never set on a server. |
| `CROPLOSS_DB_PASSWORD` | Leave as `app_dev_password` | Must equal the `APP_PASSWORD` you passed to `setup_db.sh`. Change both together if you change one. |
| `CROPLOSS_DB_HOST`, `_PORT`, `_NAME`, `_USER` | Leave | Match `dev/docker-compose.yml`. Change only if Postgres is not on localhost:5432. |
| `ORCID_CLIENT_ID`, `ORCID_CLIENT_SECRET`, `ORCID_REDIRECT_URI`, `ORCID_ENV` | Leave | Placeholders; not used while `CROPLOSS_DEV_AUTH` is set. |
| `CROPLOSS_STATE_SECRET` | Leave | Signs the ORCID login state; not used with the dev bypass. |

For a real deployment, every `ORCID_*` value must be a real one from your
ORCID developer account, `CROPLOSS_STATE_SECRET` must be a long random string
(the command is in `dev/Renviron.example`), and `CROPLOSS_DEV_AUTH` must stay
commented out.

### Start from scratch

To check the workflow is reproducible, tear down the dev environment and
follow this README again from the top:

```bash
bash dev/reset_dev.sh
```

This only tears down: it deletes the dev Postgres container, volume (all
dev data) and Docker image (`postgres:16`, re-pulled on the next start), and
`.Renviron`. If another container on your machine uses `postgres:16`, Docker
keeps the image. It rebuilds nothing, so run steps 1 and 2 again
afterwards. It does not touch `r-lib/`; to also re-test step 0, run
`rm -rf r-lib` first.

### Run

`dev/run_dev.R` reads `.Renviron` from the project root, so start R from the
project root. No edits to the script are needed. It sets a browser on Linux
automatically; see the comments at the top of the file if the browser still
does not open.

```bash
Rscript -e 'source("dev/run_dev.R")'
```
