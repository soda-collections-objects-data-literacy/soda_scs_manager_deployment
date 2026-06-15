# Redis cache (`settings.php`)

Enables Redis as Drupal’s default cache backend when the Redis container is reachable and the Redis module is installed.

## When it is written

**First install only** — if `REDIS_HOST` is set (required env in wisski-base-image entrypoint).

The entrypoint also runs `drush en redis -y` during install.

## Snippet appended to `settings.php`

```php
/**
 * Redis cache backend configuration.
 * Auto-configured by entrypoint.
 */
if (file_exists('/var/configs/redis.settings.php')) {
  include '/var/configs/redis.settings.php';
}
```

The actual Redis connection and cache bin configuration live in the included file (baked into the image).

## Included file: `/var/configs/redis.settings.php`

Repository: `wisski-base-image/config/redis/redis.settings.php`

Behaviour summary:

| Setting | Value / behaviour |
|---------|---------------------|
| `redis.connection.host` | From `REDIS_HOST` (stack service name `redis`) |
| `redis.connection.port` | From `REDIS_PORT` (default `6379`) |
| `redis.connection.persistent` | `TRUE` |
| `cache.default` | `cache.backend.redis` (after module present) |
| `cache.bins.form` | Stays on database (Drupal requirement) |
| Bootstrap/render/data/discovery bins | Redis |
| Connection failure | Logged; site continues without Redis cache |

Redis is only on the stack **internal** network; the Drupal container resolves `redis:6379`.

## Environment variables

```env
REDIS_HOST=redis
REDIS_PORT=6379
```

## Related

- wisski-base-stack `redis` service definition
- [Drupal Redis module documentation](https://project.pages.drupalcode.org/redis/)
