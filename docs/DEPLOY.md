# Production deployment (Docker)

This walks you from an empty Linux server to a running, HTTPS-protected Crop
Loss Database. For local development use the README instead.

## What you get

```
Internet ──443/80──> caddy ──> app (Shiny, port 3838) ──> db (PostgreSQL 16)
                  HTTPS certs     ORCID sign-in             data + audit trail
```

| Container | Purpose | Reachable from outside? |
|---|---|---|
| `caddy` | HTTPS, certificates (Let's Encrypt, renewed automatically) | Yes, ports 80 and 443 |
| `app` | The Shiny application | No |
| `db` | PostgreSQL, data kept in a Docker volume | No |
| `db-init` | Runs once at start-up: schema, audit trail, roles, seed data, then exits | No |

Everything is defined in [`deploy/`](../deploy).

## 1. Before you start

You need:

- A Linux server (Ubuntu 22.04+ or similar) with at least 2 GB RAM, and `sudo`.
- A hostname, such as `croploss.example.org`, with a **DNS A record pointing at
  the server's public IP**. Certificates cannot be issued until this resolves.
- Ports **80 and 443** open to the internet (cloud security group and any
  firewall). Port 22 for SSH. Nothing else needs to be open.
- An ORCID account, to register the application (step 3).

## 2. Install Docker and get the code

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER      # log out and back in afterwards
docker compose version             # must print a version
```

```bash
sudo mkdir -p /opt/croploss && sudo chown $USER /opt/croploss
git clone https://github.com/PaulMelloy/ISPPCropLossDB.git /opt/croploss
cd /opt/croploss
```

All following commands run from `/opt/croploss`.

## 3. Register the application with ORCID

1. Sign in at <https://sandbox.orcid.org> (sandbox sends email only to
   Mailinator addresses, so register a test account with one).
2. Open *Developer tools* and register an application.
3. Set the **redirect URI to exactly `https://<your-hostname>/`**, including the
   trailing slash. A mismatch is the most common reason sign-in fails.
4. Copy the client ID (`APP-...`) and client secret.

Use the sandbox first. Step 9 covers switching to real ORCID.

## 4. Configure

```bash
cp deploy/.env.example deploy/.env
chmod 600 deploy/.env
```

Edit `deploy/.env`. Every value must be set. The stack refuses to start if one
is missing.

| Variable | What to put | Notes |
|---|---|---|
| `CROPLOSS_DOMAIN` | Your hostname | No `https://`, no slash. |
| `POSTGRES_PASSWORD` | A new secret | `openssl rand -hex 24` |
| `APP_PASSWORD` | A different new secret | `openssl rand -hex 24`. Password of the restricted role the web app uses. |
| `ORCID_ENV` | `sandbox` | Change to `production` in step 9. |
| `ORCID_CLIENT_ID` | From step 3 | |
| `ORCID_CLIENT_SECRET` | From step 3 | |
| `CROPLOSS_STATE_SECRET` | A new secret | `openssl rand -hex 32` |

Use hex secrets as shown. They are placed inside a connection URL, and
characters such as `@ : / #` would break it.

You do not set `ORCID_REDIRECT_URI` or the database host: they are derived from
`CROPLOSS_DOMAIN` and the stack. The development bypass
(`CROPLOSS_DEV_AUTH`) cannot reach the container, whatever is in `.env`.

## 5. Start

```bash
docker compose -f deploy/docker-compose.yml up -d --build
```

The first run builds the app image, which installs the R packages. Expect
5 to 15 minutes. Later runs take seconds.

Check it:

```bash
docker compose -f deploy/docker-compose.yml ps -a
```

Expected: `db`, `app` and `caddy` are `running`, and `db-init` shows
`Exited (0)`. If anything is different, see Troubleshooting.

## 6. Verify

1. Open `https://<your-hostname>/`. The Browse page should load with a valid
   certificate. The first request can take a few seconds while Caddy obtains it.
2. Click **Sign in with ORCID**, sign in with your sandbox account, and confirm
   your name appears in the navbar.
3. On *Add observation*, submit a test record, then find it on *Browse* and
   open its change history.
4. Make yourself an admin (new users start as `contributor`):

   ```bash
   docker compose -f deploy/docker-compose.yml exec db psql -U croploss_owner -d croploss \
     -c "UPDATE croploss.app_user SET role = 'admin' WHERE orcid = '0000-0000-0000-0000';"
   ```

   Use your own ORCID iD in place of the zeros.

## 7. Backups

Do this before anyone enters real data.

```bash
sudo mkdir -p /var/backups/croploss && sudo chown $USER /var/backups/croploss
./deploy/backup.sh && ls -l /var/backups/croploss
```

Run it nightly with `crontab -e`:

```
15 2 * * * /opt/croploss/deploy/backup.sh
```

The script keeps 14 days of dumps **on this server**. A backup on the same
disk does not survive losing the server, so also copy `/var/backups/croploss`
elsewhere (for example object storage with `rclone`).

**Test a restore into a scratch database.** A backup that has never been
restored is not a backup:

```bash
DC="docker compose -f deploy/docker-compose.yml exec -T db"
$DC createdb -U croploss_owner restore_test
$DC pg_restore -U croploss_owner -d restore_test --no-owner < /var/backups/croploss/croploss_$(date +%F).dump
$DC psql -U croploss_owner -d restore_test -c "SELECT count(*) FROM croploss.crop_loss;"
$DC dropdb -U croploss_owner restore_test
```

The count should match the live data.

**Recovering on a new or broken server:** repeat steps 2 to 5 so the stack is
running (this recreates the roles), copy your dump onto the server, then:

```bash
docker compose -f deploy/docker-compose.yml stop app
docker compose -f deploy/docker-compose.yml exec -T db \
  pg_restore -U croploss_owner -d croploss --clean --if-exists < croploss_YYYY-MM-DD.dump
docker compose -f deploy/docker-compose.yml start app
```

## 8. Updating the app

```bash
cd /opt/croploss
git pull
docker compose -f deploy/docker-compose.yml up -d --build
```

Data and certificates live in Docker volumes and are kept.

**Database changes are not automatic.** `db-init` only builds the database when
it does not exist yet. If a release changes the files in `inst/sql/`, apply the
change by hand with `psql` (take a backup first). There is no migration tool yet.

## 9. Going live with real ORCID

1. In your real ORCID account, register the public API client under *Developer
   tools*, with the same redirect URI `https://<your-hostname>/`.
2. In `deploy/.env` set `ORCID_ENV=production` and replace `ORCID_CLIENT_ID`
   and `ORCID_CLIENT_SECRET` with the production values.
3. `docker compose -f deploy/docker-compose.yml up -d` (no rebuild needed).
4. Sign in with a real ORCID iD and confirm.

## 10. Go-live checklist

- [ ] The site loads over HTTPS and `http://` redirects to it.
- [ ] `deploy/.env` is mode 600 and is not in git (`git status` does not list it).
- [ ] The passwords and `CROPLOSS_STATE_SECRET` are random and unique.
- [ ] Only ports 22, 80 and 443 are reachable from outside.
- [ ] A nightly backup runs, is copied off the server, and a test restore succeeded.
- [ ] At least one admin exists.
- [ ] A privacy statement is published (names and ORCID iDs are stored and shown).
- [ ] `docker compose -f deploy/docker-compose.yml logs app` shows no errors after a full walkthrough.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `up` stops with `Set X in deploy/.env` | A variable is missing or empty in `deploy/.env`. |
| `db-init` is not `Exited (0)` | `docker compose -f deploy/docker-compose.yml logs db-init`. A password containing `@ : /` breaks the connection URL. Use hex secrets. |
| Browser shows a certificate error | DNS does not point at this server yet, or ports 80/443 are blocked. `docker compose -f deploy/docker-compose.yml logs caddy`. |
| Page loads but ORCID sign-in fails | The redirect URI registered with ORCID is not exactly `https://<hostname>/`, or `ORCID_ENV` does not match the credentials (sandbox vs production). |
| Sign-in works, but reloading the page signs you out | Known limitation of this prototype (login is held in the Shiny session). |
| `app` restarts repeatedly | `docker compose -f deploy/docker-compose.yml logs app`, usually a missing variable or database error. |
| Everyone shares one slow session | The app runs as a single R process. Fine for a prototype with light use. |

## Starting again from scratch

This **permanently deletes all data**, certificates and images for this stack:

```bash
docker compose -f deploy/docker-compose.yml down -v --rmi all
```

Then repeat from step 5.

## Trying it on your own machine first

Set `CROPLOSS_DOMAIN=localhost` in `deploy/.env` and run step 5. Caddy issues a
certificate from its own local authority, so the browser shows a warning you
can accept. ORCID sign-in will not work against `localhost`, but the stack,
database and pages can be checked this way. Ports 80 and 443 must be free.
