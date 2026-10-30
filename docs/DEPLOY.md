# Production deployment (Docker)

This walks you from an empty Linux server to a running, HTTPS-protected Crop
Loss Database. For local development use the README instead.

You sign in with an admin password at first. ORCID sign-in is added in step 8,
once the site's address is final.

## What you get

```
Internet ──443/80──> caddy ──> app (Shiny, port 3838) ──> db (PostgreSQL 16)
                  HTTPS certs     sign-in                   data + audit trail
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
- Your ORCID iD. The admin account is tied to it (step 3).

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

## 3. Configure

```bash
cp deploy/.env.example deploy/.env
chmod 600 deploy/.env
```

Edit `deploy/.env`:

| Variable | What to put | Notes |
|---|---|---|
| `CROPLOSS_DOMAIN` | Your hostname | No `https://`, no slash. |
| `POSTGRES_PASSWORD` | A new secret | `openssl rand -hex 24` |
| `APP_PASSWORD` | A different new secret | `openssl rand -hex 24`. Password of the restricted role the web app uses. |
| `CROPLOSS_STATE_SECRET` | A new secret | `openssl rand -hex 32` |
| `CROPLOSS_ADMIN_ORCID` | Your ORCID iD | Format `0000-0000-0000-000X`. Everything you enter while signed in with the password is attributed to it. |
| `CROPLOSS_ADMIN_PASSWORD` | A new secret | `openssl rand -hex 16`. At least 16 characters. Keep it in a password manager. |
| `ORCID_ENV` | `production` | Leave until step 8. |
| `ORCID_CLIENT_ID`, `ORCID_CLIENT_SECRET` | Leave empty | Filled in at step 8. |

Use hex secrets as shown. The database passwords are placed inside a
connection URL, and characters such as `@ : / #` would break it.

You do not set `ORCID_REDIRECT_URI` or the database host: they are derived from
`CROPLOSS_DOMAIN` and the stack. The development bypass
(`CROPLOSS_DEV_AUTH`) cannot reach the container, whatever is in `.env`.

## 4. Start

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

## 5. Verify

1. Open `https://<your-hostname>/`. The Browse page should load with a valid
   certificate. The first request can take a few seconds while Caddy obtains it.
2. Click **Admin sign-in** and enter `CROPLOSS_ADMIN_PASSWORD`. Your ORCID iD
   appears in the navbar. Your name replaces it after your first ORCID sign-in
   (step 8).
3. On *Add observation*, submit a test record, then find it on *Browse* and
   open its change history.
4. Make yourself an admin (new users start as `contributor`, and the app cannot
   change roles itself):

   ```bash
   docker compose -f deploy/docker-compose.yml exec db psql -U croploss_owner -d croploss \
     -c "UPDATE croploss.app_user SET role = 'admin' WHERE orcid = '0000-0000-0000-0000';"
   ```

   Use your `CROPLOSS_ADMIN_ORCID` in place of the zeros, then sign out and in
   again to pick up the new role.

## 6. Backups

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

**Recovering on a new or broken server:** repeat steps 2 to 4 so the stack is
running (this recreates the roles), copy your dump onto the server, then:

```bash
docker compose -f deploy/docker-compose.yml stop app
docker compose -f deploy/docker-compose.yml exec -T db \
  pg_restore -U croploss_owner -d croploss --clean --if-exists < croploss_YYYY-MM-DD.dump
docker compose -f deploy/docker-compose.yml start app
```

## 7. Updating the app

```bash
cd /opt/croploss
git pull
docker compose -f deploy/docker-compose.yml up -d --build
```

Data and certificates live in Docker volumes and are kept.

**Database changes are not automatic.** `db-init` only builds the database when
it does not exist yet. If a release changes the files in `inst/sql/`, apply the
change by hand with `psql` (take a backup first). There is no migration tool yet.

## 8. Turn on ORCID sign-in

Do this once the hostname is final: ORCID only returns users to the exact
address you register.

1. Sign in at <https://orcid.org> with your ORCID account. Your primary email
   must be verified.
2. Open your name (top right) → *Developer tools* and register a public API
   application:

   | Form field | What to enter |
   |---|---|
   | Application name | For example `ISPP Crop Loss Database`. Users see it on the ORCID sign-in page. |
   | Application URL | The site's address, `https://<your-hostname>/`. Shown to users as the app's homepage. |
   | Application description | One line on what the database is. |
   | Redirect URI | Exactly `https://<your-hostname>/`, **including the trailing slash**. A mismatch is the most common reason sign-in fails. |

   These can be edited later in *Developer tools* if the hostname changes.
3. Copy the client ID (`APP-...`) and client secret into `ORCID_CLIENT_ID` and
   `ORCID_CLIENT_SECRET` in `deploy/.env`.
4. `docker compose -f deploy/docker-compose.yml up -d` (no rebuild needed).
5. Sign out, click **Sign in with ORCID**, and sign in with the same iD as
   `CROPLOSS_ADMIN_ORCID`. Your name now shows, with your admin role and the
   records you entered with the password.
6. Turn the password off: empty `CROPLOSS_ADMIN_PASSWORD` in `deploy/.env` and
   run `docker compose -f deploy/docker-compose.yml up -d`. Once ORCID works,
   the password is only an extra way in.

**Optional: test with the ORCID sandbox first.** The sandbox lets you test
sign-in with throwaway accounts instead of real ORCID iDs. To use it, do the
steps above at <https://sandbox.orcid.org> with a new account registered to a
`@mailinator.com` address (the sandbox only emails those) and set
`ORCID_ENV=sandbox`; afterwards, put in the real ORCID credentials and set
`ORCID_ENV=production`.

## 9. Go-live checklist

- [ ] The site loads over HTTPS and `http://` redirects to it.
- [ ] `deploy/.env` is mode 600 and is not in git (`git status` does not list it).
- [ ] The passwords and `CROPLOSS_STATE_SECRET` are random and unique.
- [ ] ORCID sign-in works and `CROPLOSS_ADMIN_PASSWORD` is empty.
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
| `app` restarts repeatedly | `docker compose -f deploy/docker-compose.yml logs app`. Usually `CROPLOSS_ADMIN_PASSWORD` is shorter than 16 characters, `CROPLOSS_ADMIN_ORCID` is missing or malformed, or a database error. |
| No sign-in button | Neither `CROPLOSS_ADMIN_PASSWORD` nor both ORCID values are set in `deploy/.env`. |
| "Too many failed attempts" | Five wrong passwords in one browser session. Reload the page. Every attempt is logged: `docker compose -f deploy/docker-compose.yml logs app \| grep "Admin sign-in"`. |
| ORCID sign-in fails | The redirect URI registered with ORCID is not exactly `https://<hostname>/`, or `ORCID_ENV` does not match the credentials (sandbox vs production). |
| Sign-in works, but reloading the page signs you out | Known limitation of this prototype (sign-in is held in the Shiny session). |
| Everyone shares one slow session | The app runs as a single R process. Fine for a prototype with light use. |

## Starting again from scratch

This **permanently deletes all data**, certificates and images for this stack:

```bash
docker compose -f deploy/docker-compose.yml down -v --rmi all
```

Then repeat from step 4.

## Trying it on your own machine first

Set `CROPLOSS_DOMAIN=localhost` in `deploy/.env` and run step 4. Caddy issues a
certificate from its own local authority, so the browser shows a warning you
can accept. Admin password sign-in works, so everything except ORCID can be
checked this way. Ports 80 and 443 must be free.
