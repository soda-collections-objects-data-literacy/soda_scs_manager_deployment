# Nextcloud admin warnings and how to fix them

This guide addresses common warnings that appear in the Nextcloud admin panel (Settings → Administration → Overview).

## Reverse proxy header configuration

**Warning:** "Die Konfiguration des Reverse-Proxy-Headers ist falsch. Dies stellt ein Sicherheitsproblem dar..."

**Cause:** Nextcloud doesn't trust the reverse proxy headers or forwarded headers are not configured.

**Fix:**

1. Apply proxy settings (for existing installs):
   ```bash
   01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
   ```

2. If the warning persists, ensure the custom nginx config is in use:
   ```bash
   # From repo root
   cp 00_custom_configs/scs-nextcloud-stack/reverse-proxy/nginx.conf scs-nextcloud-stack/reverse-proxy/nginx.conf
   docker compose restart nextcloud--nextcloud-reverse-proxy
   ```

3. Verify settings inside the container:
   ```bash
   docker exec nextcloud--nextcloud php /var/www/html/occ config:system:get trusted_proxies
   docker exec nextcloud--nextcloud php /var/www/html/occ config:system:get forwarded_for_headers
   ```

---

## .mjs MIME type

**Warning:** "Der Webserver liefert `.mjs`-Dateien nicht mit dem JavaScript MIME-Typ..."

**Cause:** nginx doesn't serve `.mjs` files with the correct MIME type.

**Fix:**

Ensure custom nginx config is in use (includes `.mjs` handling):
```bash
cp 00_custom_configs/scs-nextcloud-stack/reverse-proxy/nginx.conf scs-nextcloud-stack/reverse-proxy/nginx.conf
docker compose restart nextcloud--nextcloud-reverse-proxy
```

The custom config defines `.mjs` as `application/javascript` and includes it in the static file location block.

---

## Maintenance window not configured

**Warning:** "Der Server hat keine konfigurierte Startzeit für das Wartungsfenster..."

**Cause:** Maintenance window start time and duration are not set.

**Fix:**

Apply maintenance window settings:
```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

Or manually:
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set maintenance_window_start --type integer --value=22
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set maintenance_window_length --type integer --value=6
```

This sets the maintenance window to start at 22:00 (10 PM) for 6 hours.

---

## Default phone region not set

**Warning:** "Für diese Installation ist keine Standard-Telefonregion festgelegt..."

**Cause:** `default_phone_region` is not configured.

**Fix:**

1. Add to `.env`:
   ```bash
   NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION=DE  # Use your ISO 3166-1 country code
   ```

2. Apply the setting:
   ```bash
   docker compose up -d nextcloud--nextcloud
   01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
   ```

Or manually:
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set default_phone_region --value=DE
```

---

## MIME type migrations available

**Warning:** "Eine oder mehrere MIME-Type-Migrationen sind verfügbar..."

**Cause:** After an upgrade, Nextcloud needs to update file MIME types in the database.

**Fix:**

Run the comprehensive repair script:
```bash
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
```

This runs `occ maintenance:repair --include-expensive` which includes MIME migrations. Can take a long time on large instances.

---

## Missing database indices, columns, or primary keys

**Warning:** "Einige Spalten in der Datenbank fehlen eine Index..." or similar.

**Cause:** Database schema needs updates (common after upgrades or on older installs).

**Fix:**

Run the comprehensive repair script (handles all three):
```bash
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash
```

Or manually:
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ db:add-missing-indices
docker exec nextcloud--nextcloud php /var/www/html/occ db:add-missing-columns
docker exec nextcloud--nextcloud php /var/www/html/occ db:add-missing-primary-keys
```

---

## MariaDB version warning

**Warning:** "MariaDB-Version '11.5.2-MariaDB-...' erkannt. Für optimale Leistung... wird MariaDB >= 10.6 und <= 11.4 empfohlen."

**Cause:** Nextcloud recommends MariaDB 10.6–11.4; you're running 11.5+.

**Fix:**

This is informational. MariaDB 11.5+ may work but is newer than Nextcloud's tested/recommended versions. Options:

1. **Continue using 11.5+** — Monitor for issues; report bugs if you encounter problems specific to this version.
2. **Downgrade to 11.4** — Requires database backup, container image change, and restore (not trivial).
3. **Wait for Nextcloud to update recommendations** — Future Nextcloud versions may officially support 11.5+.

For production, consider aligning with the recommended version range.

---

## Email server not configured

**Warning:** "Die E-Mail-Serverkonfiguration wurde noch nicht festgelegt oder überprüft..."

**Cause:** SMTP or email settings are not configured.

**Fix:**

Configure email in Nextcloud admin:

1. Go to Settings → Administration → Basic settings → Email server
2. Choose mode (SMTP recommended)
3. Enter SMTP server, port, credentials
4. Test with "Send email" button

See detailed guide: [Nextcloud email setup](nextcloud-email.md)

---

## .well-known URLs not resolving

**Warning:** "Der Webserver ist nicht ordnungsgemäß für die Auflösung von `.well-known`-URLs eingerichtet. Fehler bei: `/.well-known/webfinger`"

**Cause:** Either nginx is not correctly routing `.well-known` requests, redirects don't preserve the full URL through the reverse proxy chain (Traefik → nginx → Nextcloud), OR Nextcloud's `overwrite.cli.url` is set incorrectly, causing internal checks to fail.

**Fix:**

Ensure custom nginx config is in use (includes correct `.well-known` handling with full URL preservation):
```bash
cp 00_custom_configs/scs-nextcloud-stack/reverse-proxy/nginx.conf scs-nextcloud-stack/reverse-proxy/nginx.conf
docker compose restart nextcloud--nextcloud-reverse-proxy
```

The custom config handles `.well-known` URLs with 301 redirects that preserve the full URL:
- `/.well-known/carddav` → `https://$host/remote.php/dav`
- `/.well-known/caldav` → `https://$host/remote.php/dav`
- `/.well-known/webfinger` → `https://$host/index.php/.well-known/webfinger`
- `/.well-known/nodeinfo` → `https://$host/index.php/.well-known/nodeinfo`
- Other `.well-known/*` → `https://$host/index.php$request_uri`

**Why this matters with reverse proxy:**
1. **nginx redirects:** Using relative redirects like `return 301 /index.php$request_uri` fails because nginx doesn't know the external scheme (https) and hostname. By using `$scheme://$host`, we construct the full URL correctly.
2. **Nextcloud internal checks:** Nextcloud runs `.well-known` checks from inside the container using `overwrite.cli.url`. If this is set to `https://localhost`, checks will fail even if external access works. It must be set to your actual external domain.

**Fix overwrite.cli.url:**
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set overwrite.cli.url --value="https://your-nextcloud-domain.com"
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set overwritehost --value="your-nextcloud-domain.com"
```

Or use the apply script (includes this fix):
```bash
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash
```

**Test the fix:**
```bash
docs/troubleshooting/test-nextcloud-wellknown.bash your-nextcloud-domain.com
```

Or manually:
```bash
curl -I https://your-nextcloud-domain/.well-known/webfinger
# Should return 301 with Location header pointing to https://your-nextcloud-domain/index.php/.well-known/webfinger
```

**Verify in Nextcloud:**
After restart, refresh the admin panel (Settings → Administration → Overview). The `.well-known` warning should disappear within a few minutes.

**If warning persists (false positive):**

The warning may persist even though `.well-known` URLs work perfectly for external clients. This happens when:
- The Nextcloud container can't reach its own external domain from inside
- The request path through Traefik creates a routing loop
- SSL certificate verification fails for internal checks

**Verify it's a false positive:**
```bash
# Test external access (should work)
curl -I https://your-nextcloud-domain/.well-known/webfinger

# If external access works but admin warning persists, it's a false positive
```

**Option A: Suppress the check** (recommended if URLs work externally)
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:app:set serverinfo check_well_known --value=false
```

**Option B: Add domain to container hosts**
Edit `00_custom_configs/scs-nextcloud-stack/docker/docker-compose.override.yml`:
```yaml
nextcloud--nextcloud:
  extra_hosts:
    - "your-nextcloud-domain.com:172.18.0.1"  # Point to Traefik gateway
```

Then restart:
```bash
docker compose up -d nextcloud--nextcloud
```

**Note:** If external access to `.well-known` URLs works (CalDAV, CardDAV, federation), the warning is cosmetic and can be safely ignored or suppressed.

---

## AppAPI deployment daemon not configured

**Warning:** "Der Standard-Deploy-Daemon von AppAPI ist nicht eingerichtet..."

**Cause:** AppAPI (external apps framework) is installed but no deployment daemon is registered.

**Impact:** Only relevant if you want to install external apps (Ex-Apps) from the Nextcloud app ecosystem. Core Nextcloud functionality is not affected.

**Fix (if you need external apps):**

1. Go to Settings → Administration → AppAPI
2. Register a deployment daemon (Docker socket, manual, or external)
3. Set it as default

**Fix (if you don't need external apps):**

Ignore this warning or disable the AppAPI app:
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ app:disable app_api
```

---

## Warnings in logs

**Warning:** "X Warnungen in den Protokollen seit..."

**Cause:** Various issues logged by Nextcloud (performance, deprecations, errors).

**Fix:**

1. View logs: Settings → Administration → Logging
2. Review each warning and address as needed
3. Common issues:
   - **Deprecation warnings:** Inform app developers; update apps when available
   - **Performance warnings:** Optimize database, enable caching (Redis), check server resources
   - **PHP warnings:** May indicate app bugs; report to app developers
   - **File access errors:** Check file permissions on volumes

Clear old log entries after addressing issues:
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ log:manage --clear
```

---

## Caching not configured

**Warning:** "Kein Speicher-Cache konfiguriert..."

**Cause:** Nextcloud is not using Redis or APCu for caching.

**Fix:**

Redis is already included in the stack. Verify it's configured:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:get memcache.distributed
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:get memcache.locking
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:get redis host
```

If not configured, set Redis:
```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set redis host --value=nextcloud--redis
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set redis port --value=6379 --type=integer
```

---

## Background jobs not running

**Warning:** "Last background job execution ran X ago. Something seems wrong."

**Cause:** Nextcloud cron is not running or configured incorrectly.

**Fix:**

1. Check background jobs setting: Settings → Administration → Basic settings → Background jobs
2. Ensure "Cron" is selected (not AJAX or Webcron)
3. Verify cron is running inside the container:
   ```bash
   docker exec nextcloud--nextcloud cat /var/spool/cron/crontabs/www-data
   ```

   Should show:
   ```
   */5 * * * * php -f /var/www/html/cron.php
   ```

4. If missing, the Nextcloud image should set this up automatically. Restart the container:
   ```bash
   docker compose restart nextcloud--nextcloud
   ```

5. Manually trigger cron to test:
   ```bash
   docker exec -u www-data nextcloud--nextcloud php /var/www/html/cron.php
   ```

---

## Summary: Fix all common warnings

Run these commands from the repo root to address most warnings at once:

```bash
# 1. Ensure custom nginx config is in use (fixes .mjs, .well-known, proxy headers)
cp 00_custom_configs/scs-nextcloud-stack/reverse-proxy/nginx.conf scs-nextcloud-stack/reverse-proxy/nginx.conf
docker compose restart nextcloud--nextcloud-reverse-proxy

# 2. Apply proxy, maintenance window, and phone region settings
01_scripts/scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash

# 3. Run comprehensive maintenance (MIME migrations, DB indices, columns, keys)
01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash

# 4. Refresh admin panel and check remaining warnings
```

For email and AppAPI, configure manually via the Nextcloud admin UI as needed.
