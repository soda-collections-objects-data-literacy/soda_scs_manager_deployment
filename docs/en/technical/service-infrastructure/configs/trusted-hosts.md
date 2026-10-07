# Trusted hosts (`settings.php`)

Drupal’s [trusted host security](https://www.drupal.org/docs/administering-a-drupal-site/security-in-drupal/trusted-host-settings) restricts which `Host` request headers are accepted. Required when the site is reachable under a public domain.

## When it is written

**First install only** (not updated on container restart).

Source: `entrypoint.sh` after `drush si`.

## Environment variable

`DRUPAL_TRUSTED_HOSTS` — pipe-separated **PCRE patterns** (not comma-separated).

Example for SCS Manager–created stacks:

```env
DRUPAL_PROXY_ADDRESSES=auto
DRUPAL_TRUSTED_HOSTS=^wisski-production\.wisski\.dev-scs\.sammlungen\.io$|^raw\.wisski-production\.wisski\.dev-scs\.sammlungen\.io$
```

SCS Manager builds this automatically from the instance domain (public + `raw.` prefix).

## Snippet appended to `settings.php`

```php
$settings['trusted_host_patterns'] = [
  "^wisski-production\\.wisski\\.dev-scs\\.sammlungen\\.io$",
  "^raw\\.wisski-production\\.wisski\\.dev-scs\\.sammlungen\\.io$",
];
```

## Notes

- Patterns are **regex**; dots in the domain must be escaped (`\.`).
- Both the Varnish front door and the `raw.*` Traefik route need to be listed.
- Changing the public domain after install requires **manual** edit of `settings.php` or site reinstall.
- Trusted hosts are independent of reverse proxy: they validate `Host`, not `X-Forwarded-Host`.

## Related

- [WissKI stack URLs](../wisski-stack/index.md#public-urls-and-traefik-routers)
