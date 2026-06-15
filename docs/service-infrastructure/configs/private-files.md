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

## Related

- wisski-base-stack `docker-compose.yml` volume definitions
