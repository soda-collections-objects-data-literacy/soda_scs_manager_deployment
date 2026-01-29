# Updates and maintenance

This guide covers updating services (especially Nextcloud) and handling post-update tasks.

---

## General update strategy

Services in this deployment are defined by Docker images with version tags (e.g. `nextcloud:31.0-fpm`, `onlyoffice/documentserver:8.3`). To update a service:

1. **Check the changelog** of the service for breaking changes, new requirements, or migration notes.
2. **Update the image tag** in the relevant `docker-compose.yml` or override file.
3. **Pull the new image** and recreate the container.
4. **Run post-update tasks** (migrations, repairs, config updates) as documented by the service.
5. **Verify** the service is working correctly.

Always back up databases and volumes before major version upgrades.

---

## Updating Nextcloud

Nextcloud is a stateful service with a database, file storage, and apps. Updates require care to avoid data loss or broken functionality.

### Before updating

1. **Back up database and volumes**

   Use the provided backup script from the repo root:

   ```bash
   01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
   ```

   This script will:
   - Enable Nextcloud maintenance mode
   - Back up the database to `/srv/backups/nextcloud/nextcloud-db_TIMESTAMP.sql`
   - Back up the nextcloud-data volume to `/srv/backups/nextcloud/nextcloud-data_TIMESTAMP.tar.gz`
   - Optionally back up the onlyoffice-data volume
   - Disable maintenance mode
   - Create timestamped backups for easy identification

   Manual backup (alternative):

   ```bash
   docker exec scs--database mariadb-dump -u root -p"${SCS_DB_ROOT_PASSWORD}" "${NEXTCLOUD_DB_NAME}" > nextcloud-backup-$(date +%Y%m%d).sql
   ```

3. **Check Nextcloud release notes**

   Visit [Nextcloud releases](https://nextcloud.com/changelog/) and read the changelog for the target version. Note any:
   - PHP version requirements.
   - Database version requirements (e.g. MariaDB 10.6–11.4).
   - Breaking changes or removed/changed apps.
   - Recommended upgrade paths (e.g. must upgrade to 30.x before 31.x).

4. **Check app compatibility**

   Some apps (e.g. Social Login, OnlyOffice connector) may need updates or may not yet support the new Nextcloud version. Check the Nextcloud app store or app repositories for compatibility.

### Performing the update

1. **Update the image tag**

   Edit `scs-nextcloud-stack/docker-compose.yml`:

   ```yaml
   nextcloud--nextcloud:
     image: nextcloud:31.0-fpm  # Change to nextcloud:32.0-fpm (example)
   ```

2. **Pull the new image and recreate the container**

   From the repo root:

   ```bash
   docker compose pull nextcloud--nextcloud
   docker compose up -d nextcloud--nextcloud
   ```

   The Nextcloud container will detect the version change and run database migrations automatically on startup. **This can take several minutes to hours** depending on the size of your instance and the number of migrations. Monitor logs:

   ```bash
   docker compose logs -f nextcloud--nextcloud
   ```

   Look for messages like:
   - "Nextcloud is already the latest version or newer" (if already up to date).
   - "Nextcloud is in maintenance mode" (during migration).
   - "Starting web server" (when ready).

3. **Wait for the upgrade to complete**

   Do not stop the container during migration. If the container exits with an error, check the logs and consult Nextcloud documentation for the specific error.

### Post-update tasks

After the update completes and Nextcloud is running, perform these tasks from the repo root:

1. **Disable maintenance mode** (if still enabled)

   ```bash
   docker exec nextcloud--nextcloud php /var/www/html/occ maintenance:mode --off
   ```

2. **Run maintenance and repair tasks**

   This script runs all common post-update maintenance tasks (MIME migrations, missing indices, columns, and primary keys):

   ```bash
   01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
   ```

   This can take a long time on large instances. The script runs:
   - `occ maintenance:repair --include-expensive` (MIME type migrations, etc.)
   - `occ db:add-missing-indices`
   - `occ db:add-missing-columns`
   - `occ db:add-missing-primary-keys`

3. **Update apps**

   After a Nextcloud upgrade, apps may need updates:

   ```bash
   docker exec nextcloud--nextcloud php /var/www/html/occ app:update --all
   ```

   Or use the Nextcloud web UI (Admin → Apps → Updates).

4. **Check app compatibility**

   Some apps may be disabled during the upgrade if they are incompatible with the new version. Check the Apps page in the Nextcloud admin panel and re-enable or update apps as needed. If an app is not yet compatible, check for a new version or temporarily disable it until an update is available.

5. **Re-apply proxy and region settings** (if needed)

   If the upgrade reset any config (uncommon but possible), re-run:

   ```bash
   01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
   ```

6. **Check admin warnings**

   Log in to Nextcloud as admin and visit Settings → Administration → Overview. If you ran the repair script (step 2), most database-related warnings should already be resolved. If any warnings remain, they will suggest specific `occ` commands to run inside the container.

7. **Test functionality**

   - Log in as a user.
   - Upload/download files.
   - Test OnlyOffice (open a document).
   - Test SSO/Keycloak login.
   - Check background jobs (Settings → Administration → Basic settings → Background jobs; should be "Cron" and last job should have run recently).

### Common issues during updates

#### Maintenance mode stuck

**Symptom:** Nextcloud shows "System in maintenance mode" after upgrade.

**Fix:**

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ maintenance:mode --off
```

Check logs for errors that prevented the upgrade from completing.

#### Database migration fails

**Symptom:** Container logs show SQL errors or "Failed to run migration".

**Fixes:**

- Check MariaDB version compatibility (Nextcloud 31 recommends MariaDB 10.6–11.4).
- Restore from backup and retry the upgrade after fixing the issue.
- Consult the Nextcloud community forum or GitHub issues for the specific error.

#### Apps disabled after upgrade

**Symptom:** Apps like Social Login, OnlyOffice, or custom apps are disabled.

**Fix:**

Check the app list and re-enable compatible apps:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ app:list
docker exec nextcloud--nextcloud php /var/www/html/occ app:enable <app-name>
```

If an app is incompatible, wait for an update or disable it until a compatible version is available.

#### OnlyOffice or SSO broken after upgrade

**Symptom:** OnlyOffice documents fail to open, or Keycloak login fails.

**Fixes:**

- **OnlyOffice:** Check that the OnlyOffice app is still enabled and configured correctly. Visit Settings → Administration → OnlyOffice and verify the document server URL and JWT secret match your `.env`.
- **SSO:** Check that the Social Login app is enabled and its settings (issuer, client ID, secret) match your Keycloak realm. Re-run the post-install hook or manually reconfigure the app.

#### Reverse proxy warnings reappear

**Symptom:** Admin panel shows "The reverse proxy header configuration is incorrect".

**Fix:**

Re-apply proxy settings:

```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

#### Performance issues after upgrade

**Symptom:** Nextcloud is slow or unresponsive.

**Fixes:**

- Run `occ db:add-missing-indices` to add any missing database indices.
- Check that Redis is running and Nextcloud is using it for caching (Settings → Administration → Overview should not show a caching warning).
- Check container resource limits (CPU, memory) and adjust if needed.

---

## Updating other services

### OnlyOffice Document Server

OnlyOffice version is defined in `scs-nextcloud-stack/docker-compose.yml`:

```yaml
nextcloud--onlyoffice-document-server:
  image: onlyoffice/documentserver:8.3
```

To update:

1. Check [OnlyOffice changelog](https://github.com/ONLYOFFICE/DocumentServer/releases) for breaking changes.
2. Update the image tag.
3. Pull and recreate:

   ```bash
   docker compose pull nextcloud--onlyoffice-document-server
   docker compose up -d nextcloud--onlyoffice-document-server
   ```

4. Test by opening a document in Nextcloud.

### Keycloak

Keycloak version is in `keycloak/docker-compose.yml` (env: `KC_VERSION`). Follow [Keycloak upgrade guide](https://www.keycloak.org/docs/latest/upgrading/index.html).

Important:

- Back up the Keycloak database before upgrading.
- Check for breaking changes in the [release notes](https://www.keycloak.org/docs/latest/release_notes/index.html).
- Re-import realm if schema changes require it (uncommon).

### JupyterHub, Drupal, OpenGDB

Each service has its own upgrade process. General steps:

1. Back up the database.
2. Check service documentation for upgrade notes.
3. Update the image tag in the relevant compose file.
4. Pull and recreate the container.
5. Run any post-upgrade migrations or scripts as documented.

---

## Rollback

If an update fails or causes issues, you can restore from backup.

### Using the restore script (recommended)

From the repo root:

```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

The script will:
- List available backups with timestamps
- Stop Nextcloud services
- Drop and recreate the database
- Restore the database from the selected backup
- Restore the nextcloud-data volume (if backup exists)
- Restart services and disable maintenance mode

### Manual rollback

If you need to manually restore:

1. **Stop the affected service**:

   ```bash
   docker compose stop nextcloud--nextcloud nextcloud--nextcloud-reverse-proxy
   ```

2. **Restore the database backup**:

   ```bash
   docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${NEXTCLOUD_DB_NAME};"
   docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE ${NEXTCLOUD_DB_NAME};"
   docker exec -i scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" "${NEXTCLOUD_DB_NAME}" < /srv/backups/nextcloud/nextcloud-db_TIMESTAMP.sql
   ```

3. **Revert the image tag** in the compose file to the previous version.

4. **Recreate the container**:

   ```bash
   docker compose up -d nextcloud--nextcloud nextcloud--nextcloud-reverse-proxy
   ```

5. **Verify** the service is working with the old version and backed-up data.

---

## Backup and restore

### Backup script

The deployment includes a comprehensive backup script for Nextcloud:

```bash
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

**What it backs up:**
- Nextcloud database (MariaDB dump)
- nextcloud-data volume (all files, apps, config)
- onlyoffice-data volume (optional, prompted)

**Backup location:** `/srv/backups/nextcloud/` with timestamped filenames:
- `nextcloud-db_YYYYMMDD_HHMMSS.sql`
- `nextcloud-data_YYYYMMDD_HHMMSS.tar.gz`
- `onlyoffice-data_YYYYMMDD_HHMMSS.tar.gz` (if backed up)

**Features:**
- Enables maintenance mode during backup for data consistency
- Creates compressed archives for volumes
- Shows backup sizes
- Disables maintenance mode automatically after backup
- Automatically creates `/srv/backups/nextcloud/` if it doesn't exist

**Usage:**

```bash
cd /var/deploy/soda_scs_manager_deployment
01_scripts/scs-nextcloud-stack/backup-nextcloud.bash
```

**Note:** Ensure the user running the script has write permission to `/srv/backups/`. If needed:
```bash
sudo mkdir -p /srv/backups
sudo chown $(whoami):$(whoami) /srv/backups
```

**Best practices:**
- Run backups before updates or major changes
- Schedule regular backups (e.g., daily via cron)
- Store backups off-site or on a separate disk
- Test restore procedure periodically
- Keep multiple backup generations (don't delete old backups immediately)

### Restore script

To restore from a backup:

```bash
01_scripts/scs-nextcloud-stack/restore-nextcloud.bash
```

The script will:
- List available backups with sizes
- Prompt you to select which backup to restore
- Show what will be restored (database and/or data volume)
- Require explicit confirmation (must type "YES")
- Stop services, restore data, and restart services

**WARNING:** Restore will overwrite all current Nextcloud data. Only use when intentionally rolling back or recovering from data loss.

## Scheduled maintenance

### Nextcloud background jobs

Nextcloud uses cron for background jobs (file scans, cleanup, etc.). The deployment uses the Docker entrypoint hook to set up cron inside the Nextcloud container. Verify cron is running:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ background:cron
```

Check last run time in Settings → Administration → Basic settings → Background jobs.

### Database maintenance

MariaDB should be backed up regularly. Use `mariadb-dump` (as shown above) and store backups securely. Consider setting up a cron job on the host to automate backups.

### Cleaning up old images and volumes

After updates, old Docker images may remain. Clean them up periodically:

```bash
docker image prune -a
docker volume prune  # Caution: only removes unused volumes
```

---

## Summary checklist for Nextcloud updates

- [ ] Run `01_scripts/scs-nextcloud-stack/backup-nextcloud.bash` (backs up DB and volumes).
- [ ] Check Nextcloud release notes and upgrade path.
- [ ] Update image tag in compose file.
- [ ] Pull new image and recreate container.
- [ ] Monitor logs during migration.
- [ ] Disable maintenance mode (if stuck).
- [ ] Run `01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash` (comprehensive maintenance).
- [ ] Update all apps (`occ app:update --all`).
- [ ] Re-enable any disabled apps (if compatible).
- [ ] Check admin warnings for any remaining issues.
- [ ] Re-apply proxy/region settings if needed (use `apply-nextcloud-proxy-and-region.bash`).
- [ ] Test file upload, OnlyOffice, SSO, background jobs.
