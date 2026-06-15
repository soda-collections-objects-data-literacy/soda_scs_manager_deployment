# WissKI Drupal configuration snippets

The [wisski-base-image](https://github.com/soda-collections-objects-data-literacy/wisski-base-image) entrypoint configures each WissKI instance by appending blocks to:

```
/opt/drupal/web/sites/default/settings.php
```

(`/var/www/html/sites/default/settings.php` is a symlink to that path.)

Persistent site state lives in the Docker volume `{SERVICE_NAME}--drupal-sites`. Code in the image is immutable; only `settings.php` customizations and uploaded files survive container recreation.

## When snippets are applied

| Phase | What runs |
|-------|-----------|
| **First install** (`drush si`, marker `.wisski-install-complete` not present) | Trusted hosts, private files path, Redis include, reverse proxy (if enabled), then WissKI recipes and modules |
| **Every container start** (install complete) | `sync-reverse-proxy.sh` — refreshes or removes the [reverse proxy](reverse-proxy.md) block from `DRUPAL_PROXY_ADDRESSES` |
| **Image upgrade** (package version changed) | `drush updatedb` + cache rebuild |

Install-time snippets are **not** re-appended on restart. Reverse proxy is the exception: it is synchronized on every boot so network CIDRs and env changes take effect without reinstalling the site.

## Environment variables → settings

| Env variable | Settings snippet | Doc |
|--------------|------------------|-----|
| `DRUPAL_TRUSTED_HOSTS` | `trusted_host_patterns` | [trusted-hosts.md](trusted-hosts.md) |
| `DRUPAL_PRIVATE_FILES_DIR` | `file_private_path` | [private-files.md](private-files.md) |
| `REDIS_HOST` / `REDIS_PORT` | include `redis.settings.php` | [redis.md](redis.md) |
| `DRUPAL_PROXY_ADDRESSES` | reverse proxy block | [reverse-proxy.md](reverse-proxy.md) |

Other Drupal configuration (OpenID Connect, WissKI adapters, page cache TTL, etc.) is applied via **Drush** during first install, not as `settings.php` snippets.

## Source files in wisski-base-image

| Runtime | Repository path |
|---------|-----------------|
| Entrypoint orchestration | `entrypoint.sh` |
| Reverse proxy sync | `config/drupal/sync-reverse-proxy.sh`, `config/drupal/lib/reverse-proxy.py` |
| Redis settings include | `config/redis/redis.settings.php` (mounted in image at `/var/configs/redis.settings.php`) |

## Inspecting a live instance

```bash
# Env (Portainer stack)
docker exec wisski-production--drupal printenv DRUPAL_PROXY_ADDRESSES

# Tail of settings.php
docker exec wisski-production--drupal tail -30 /opt/drupal/web/sites/default/settings.php

# Verify HTTPS URL generation (after proxy fix)
curl -sL https://wisski-production.wisski.dev-scs.sammlungen.io/ | grep -o 'href="https://[^"]*' | head
```

## Snippet reference

- [trusted-hosts.md](trusted-hosts.md) — `$settings['trusted_host_patterns']`
- [private-files.md](private-files.md) — `$settings['file_private_path']`
- [redis.md](redis.md) — Redis cache backend include
- [reverse-proxy.md](reverse-proxy.md) — `$settings['reverse_proxy']` and related keys
