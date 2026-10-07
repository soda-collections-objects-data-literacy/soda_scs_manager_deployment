# Reverse proxy (`settings.php`)

Tells Drupal to trust `X-Forwarded-*` headers from the reverse proxy chain (Traefik → Varnish → Nginx) so generated URLs use **https**, the **public hostname**, and logs show the **real client IP**.

## When it is written

- **First install:** if `DRUPAL_PROXY_ADDRESSES` is not `none` / empty
- **Every boot:** `sync-reverse-proxy.sh` replaces the block (idempotent)
- **Disabled:** `DRUPAL_PROXY_ADDRESSES=none` removes the block on boot

Managed by: `config/drupal/sync-reverse-proxy.sh` + `config/drupal/lib/reverse-proxy.py` in wisski-base-image.

## Environment variable

| Value | Meaning |
|-------|---------|
| `auto` | Detect CIDRs from container IPv4 interfaces (recommended on SCS) |
| `none` | No reverse proxy configuration |
| `172.20.0.0/16\|192.168.64.0/20` | Explicit pipe-separated trusted proxy CIDRs |

Set on the Portainer stack as `DRUPAL_PROXY_ADDRESSES`. SCS Manager default: `auto` (see **WissKI settings** in SCS Manager).

## Snippet appended to `settings.php`

```php
/**
 * Reverse proxy configuration.
 * Auto-configured by entrypoint.
 */
$settings["reverse_proxy"] = TRUE;
$settings["reverse_proxy_trusted_headers"] = \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO;
$settings['omit_vary_cookie'] = TRUE;
$settings['reverse_proxy_addresses'] = ["172.20.0.42/16", "192.168.64.3/20"];
```

The last line is an example from `auto` detection; actual CIDRs depend on the stack’s Docker networks.

## Setting reference

| Key | Purpose |
|-----|---------|
| `reverse_proxy` | Enable Symfony reverse proxy middleware |
| `reverse_proxy_trusted_headers` | Which `X-Forwarded-*` headers Drupal may use |
| `omit_vary_cookie` | Avoid `Vary: Cookie` issues behind Varnish |
| `reverse_proxy_addresses` | CIDRs of **direct HTTP peers of Nginx** (Varnish on main path, Traefik on `raw.*` path) |

## What belongs in `reverse_proxy_addresses`

| IP / network | Trust? |
|--------------|--------|
| Varnish on `internal` network | Yes (main URL) |
| Traefik on `reverse-proxy` | Yes (`raw.*` URL) |
| Client public IP | **No** |
| Random `172.18.0.0/16` if stack uses `172.20.0.0/16` | **No** — headers ignored, URLs stay `http://` |

`REMOTE_ADDR` at PHP is always the IP of whoever connected to **Nginx:80** (Varnish or Traefik), not Nginx itself (PHP-FPM uses a Unix socket).

## Symptoms when misconfigured

| Symptom | Likely cause |
|---------|----------------|
| Links use `http://` | `reverse_proxy_addresses` does not include Varnish/Traefik CIDR |
| Wrong domain in URLs | Missing/wrong `X-Forwarded-Host` (check Traefik/Varnish) |
| Client IP = `172.x` / `192.168.x` in Drupal | `reverse_proxy` off or addresses wrong |
| Settings not updating after env change | Old image without `sync-reverse-proxy.sh`; recreate container |

## Related

- [WissKI stack HTTP path](../wisski-stack/index.md)
- [Reverse proxy knowledge base](../../knowledge-base/reverse-proxy-backend-config-knowledge-base.md)
