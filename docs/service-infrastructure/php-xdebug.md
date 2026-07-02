# PHP debugging (Xdebug) — SCS Manager

## Production

Do **not** mount `scs-manager-stack/configs/php/zz-xdebug-debug.ini` in production. That file:

- Enables Xdebug in `debug,develop` mode
- Previously disabled OPcache (`opcache.enable = 0`), which triggers Drupal’s status warning *PHP-OPcode-Caching nicht aktiviert*

The production `docker-compose.override.yml` files intentionally omit this mount so OPcache stays enabled from the image defaults (`zz-opcache-recommended.ini`).

Verify after deploy:

```bash
docker exec scs-manager--drupal php -i | grep 'opcache.enable =>'
# opcache.enable => On => On
```

## Local development

To debug with Cursor/VS Code, temporarily add the volume to your override (or a local `docker-compose.override.local.yml`):

```yaml
services:
  scs-manager--drupal:
    volumes:
      - ./scs-manager-stack/configs/php/zz-xdebug-debug.ini:/usr/local/etc/php/conf.d/zz-xdebug-debug.ini:ro
```

Then recreate the container:

```bash
docker compose up -d --force-recreate scs-manager--drupal
```

Xdebug uses **trigger** mode (`XDEBUG_TRIGGER=CURSOR` or browser extension). Normal page loads keep OPcache on unless you uncomment `opcache.enable = 0` in the ini file for difficult breakpoint sessions.

Remove the mount and recreate the container before returning to production.
