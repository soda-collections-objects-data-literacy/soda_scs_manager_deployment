# Private files path (`settings.php`)

Sets Drupal’s private files directory outside the web root so sensitive uploads are not served directly by Nginx.

## When it is written

**First install only.**

Source: `entrypoint.sh` after trusted hosts.

## Environment variable

`DRUPAL_PRIVATE_FILES_DIR` — default in wisski-base-stack: `/opt/drupal/private-files`

Persisted in Docker volume `{SERVICE_NAME}--drupal-private-files`.

## Snippet appended to `settings.php`

```php
$settings["file_private_path"] = "/opt/drupal/private-files";
```

## Layout

| Path | Mounted volume | Web accessible |
|------|----------------|----------------|
| `/opt/drupal/web/sites` | `drupal-sites` | Yes (`sites/default/files` is public) |
| `/opt/drupal/private-files` | `drupal-private-files` | No |

The entrypoint creates the directory and sets ownership for `www-data` before install completes.

## SCS Manager snapshots

SCS Manager stores snapshot archives under `private://snapshots/…` on disk at `/var/scs-manager/snapshots` (host bind mount, typically `/srv/backups/scs-manager/snapshots`). For Drupal to resolve those paths, set in `settings.php`:

```php
$settings['file_private_path'] = '/var/scs-manager';
```

(`00_custom_configs/scs-manager-stack/drupal/file-private-path.settings.php` documents this layout.)

### Private Files Download Permission (PFDP)

If the **Private Files Download Permission** (`pfdp`) module is enabled, it denies every `private://` download unless a matching directory rule exists. Snapshot access is enforced in `soda_scs_manager_file_download()` (owner + `view soda scs snapshot`); PFDP must **bypass** `/snapshots` or owners receive HTTP 403 even when logged in.

`soda_scs_manager` creates this rule on install and via `update_11024`:

| PFDP directory ID | Path | Bypass |
|-------------------|------|--------|
| `scs_manager_snapshots` | `/snapshots` | Yes |

Manual check: **Configuration → Media → Private files download permission** — entry `/snapshots` with **Bypass** enabled.

After changing `file_private_path` or PFDP rules, run `drush cr`.

## Related

- wisski-base-stack `docker-compose.yml` volume definitions
