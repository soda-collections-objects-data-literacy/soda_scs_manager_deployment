# Nextcloud scripts

This directory contains scripts for managing the Nextcloud stack. All scripts should be run from the **repository root** (where `.env` and `docker-compose.yml` are located).

## Available scripts

### `pre-install.bash`

**Purpose:** Pre-installation setup for Nextcloud.

**What it does:**
- Creates Nextcloud database in MariaDB
- Creates Nextcloud database user with privileges

**When to run:** Once before first startup (automatically called by `start.sh`).

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/pre-install.bash
```

---

### `start-services.bash`

**Purpose:** Start Nextcloud services.

**What it does:**
- Starts Nextcloud, OnlyOffice, reverse proxies, and Redis containers

**When to run:** To start Nextcloud stack after it has been stopped.

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/start-services.bash
```

---

### `stop-services.bash`

**Purpose:** Stop Nextcloud services.

**What it does:**
- Stops all Nextcloud stack containers

**When to run:** For maintenance, before updates, or to save resources.

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/stop-services.bash
```

---

### `backup-nextcloud.bash`

**Purpose:** Create timestamped backups of Nextcloud database and volumes.

**What it does:**
- Enables Nextcloud maintenance mode
- Backs up the Nextcloud database (MariaDB dump)
- Backs up the nextcloud-data volume (compressed tar.gz)
- Optionally backs up the onlyoffice-data volume
- Disables maintenance mode
- Stores backups in `backups/nextcloud/` with timestamps

**When to run:**
- Before updates or major changes
- As part of regular backup schedule (e.g., daily via cron)

**Backup files created:**
- `/srv/backups/nextcloud/nextcloud-db_YYYYMMDD_HHMMSS.sql`
- `/srv/backups/nextcloud/nextcloud-data_YYYYMMDD_HHMMSS.tar.gz`
- `/srv/backups/nextcloud/onlyoffice-data_YYYYMMDD_HHMMSS.tar.gz` (optional)

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

**Notes:**
- Backup can take a long time depending on data size
- Backups are stored in `/srv/backups/nextcloud/`; move to off-site storage for safety
- Old backups are not automatically deleted; manage retention manually
- Script creates backup directory automatically; ensure write permissions on `/srv/backups/`

---

### `restore-nextcloud.bash`

**Purpose:** Restore Nextcloud from a timestamped backup.

**What it does:**
- Lists available backups with sizes
- Prompts for backup selection
- Stops Nextcloud services
- Drops and recreates the database
- Restores database from selected backup
- Restores nextcloud-data volume (if backup exists)
- Restarts services

**When to run:**
- To roll back after a failed update
- To recover from data corruption or loss

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

**WARNING:** This will overwrite all current Nextcloud data. Only use when intentionally rolling back or recovering.

**Notes:**
- Interactive script; requires explicit confirmation (type "YES")
- Looks for backups in `/srv/backups/nextcloud/`
- Matches database and volume backups by timestamp

---

### `run-nextcloud-repair.bash`

**Purpose:** Run comprehensive Nextcloud maintenance and repair tasks.

**What it does:**
- Runs `occ maintenance:repair --include-expensive` (MIME migrations, general repairs)
- Adds missing database indices
- Adds missing database columns
- Adds missing primary keys

**When to run:**
- After Nextcloud updates
- When admin panel shows warnings (MIME migrations, missing indices, etc.)
- Periodically for maintenance

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
```

**Notes:**
- Can take a long time on large instances (especially the expensive repair)
- Safe to run multiple times; only adds what's missing
- Check Nextcloud admin panel after running to verify warnings are resolved

---

### `apply-nextcloud-proxy-and-region.bash`

**Purpose:** Apply or re-apply reverse proxy and phone region settings to an existing Nextcloud install.

**What it does:**
- Sets trusted proxies (localhost, private IP ranges)
- Sets forwarded headers (`X-Forwarded-For`, `X-Forwarded-Host`, `X-Forwarded-Proto`)
- Sets maintenance window (22:00, 6 hours)
- Sets default phone region (if `NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION` is in `.env`)

**When to run:**
- On existing installs to fix reverse proxy security warnings
- After changing proxy configuration
- When admin panel shows proxy header warnings

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

**Notes:**
- For new installs, these settings are applied by the post-installation hook
- Safe to run multiple times; settings are idempotent
- Requires `NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION` in `.env` (optional, e.g., `DE`)

---

### `configure-nextcloud-email.bash`

**Purpose:** Apply email configuration from environment variables to an existing Nextcloud install.

**What it does:**
- Reads email settings from `.env`
- Configures SMTP mode, host, port, encryption
- Sets authentication credentials
- Sets from address and domain

**When to run:**
- After adding email settings to `.env`
- To update email configuration without using admin UI
- During automated setup/provisioning

**Required environment variables:**
- `NEXTCLOUD_NEXTCLOUD_MAIL_MODE` (smtp, sendmail, or php)
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST`
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PORT`
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_SECURE` (tls or ssl)
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_AUTH` (1 or 0)
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME`
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PASSWORD`
- `NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS`
- `NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN`

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/configure-nextcloud-email.bash
```

**Notes:**
- Email settings are also applied automatically by post-installation hook if env vars are set
- For new installs, add env vars before first start; for existing installs, run this script
- Test email after configuration: Settings → Administration → Basic settings → Send email

---

### `clean-nextcloud.bash`

**Purpose:** Completely remove Nextcloud (database, volumes, containers).

**What it does:**
- Stops and removes all Nextcloud containers and volumes
- Drops Nextcloud database and user from MariaDB

**When to run:**
- To start fresh with a clean Nextcloud installation
- When troubleshooting major issues

**Usage:**
```bash
01_scripts/scs-nextcloud-stack/clean-nextcloud.bash
```

**WARNING:** This permanently deletes all Nextcloud data. Back up first!

**Notes:**
- Requires confirmation (must type "yes")
- Does not back up data automatically; use `backup-nextcloud.bash` first
- After cleaning, run `pre-install.bash` before starting services again

---

## Typical workflows

### First installation
1. `pre-install.bash` (automatically called by `start.sh`)
2. `docker compose up -d` (from repo root)
3. Configure via Nextcloud admin panel

### Regular backup
```bash
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
# Move backups to off-site storage
```

### Update Nextcloud
1. `backup-nextcloud.bash`
2. Edit `scs-nextcloud-stack/docker-compose.yml` (change image tag)
3. `docker compose pull nextcloud--nextcloud`
4. `docker compose up -d nextcloud--nextcloud`
5. Monitor logs: `docker compose logs -f nextcloud--nextcloud`
6. `run-nextcloud-repair.bash`
7. Test functionality

### Restore after failed update
1. `restore-nextcloud.bash`
2. Select the backup from before the update
3. Confirm restoration
4. Verify functionality

### Fix admin warnings
```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
01_scripts/scs-nextcloud-stack/configure-nextcloud-email.bash  # if email env vars are set
```

### Configure email (existing install)
```bash
# Add email settings to .env, then:
01_scripts/scs-nextcloud-stack/configure-nextcloud-email.bash
```

---

## Environment variables required

All scripts expect these variables in `.env`:

**Required:**
- `SCS_DB_ROOT_PASSWORD` — MariaDB root password
- `NEXTCLOUD_DB_NAME` — Nextcloud database name (default: `nextcloud`)
- `NEXTCLOUD_DB_USER` — Nextcloud database user (default: `nextcloud`)
- `NEXTCLOUD_DB_PASSWORD` — Nextcloud database password

**Optional:**
- `NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION` — ISO 3166-1 code (e.g., `DE`)
- `NEXTCLOUD_NEXTCLOUD_MAIL_MODE` — Email mode: smtp, sendmail, or php
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST` — SMTP server hostname
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PORT` — SMTP port (default: 587)
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_SECURE` — Encryption: tls or ssl
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_AUTH` — Authentication: 1 or 0
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME` — SMTP username
- `NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PASSWORD` — SMTP password
- `NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS` — From address (e.g., noreply)
- `NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN` — Domain for from address (e.g., yourdomain.com)

## Documentation

See the full documentation:
- [Updates and maintenance](../../docs/maintenance/updates.md)
- [Post-configuration checklist](../../docs/post-configuration/checklist.md)
