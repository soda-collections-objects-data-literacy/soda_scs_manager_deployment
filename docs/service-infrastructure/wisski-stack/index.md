# WissKI stack infrastructure

WissKI instances on the SCS deployment are **not** part of the root `COMPOSE_FILE`. Each instance is a standalone Docker Compose stack deployed via **Portainer** (triggered by SCS Manager) from the [wisski-base-stack](https://github.com/soda-collections-objects-data-literacy/wisski-base-stack) repository and the [wisski-base-image](https://github.com/soda-collections-objects-data-literacy/wisski-base-image).

This page describes the HTTP path, containers, networks, and how proxy headers reach Drupal.

## Containers per instance

| Container | Image | Role |
|-----------|-------|------|
| `{SERVICE_NAME}--varnish` | `scs-varnish` | HTTP cache; public entry point for the instance domain |
| `{SERVICE_NAME}--drupal` | `wisski-base-image-*` | Nginx + PHP-FPM + Drupal/WissKI in one container |
| `{SERVICE_NAME}--redis` | `redis:7.4-alpine` | Cache/session backend for Drupal (internal network only) |

There is **no separate Nginx container** in front of Varnish. Nginx runs **inside** the Drupal container and terminates HTTP before PHP-FPM (Unix socket).

Database and triplestore are **shared SCS services** (`scs--database`, OpenGDB/RDF4J), not part of the per-instance compose file.

## Networks

Each stack gets two Docker networks:

| Network | Purpose |
|---------|---------|
| `reverse-proxy` (external) | Traefik reaches Varnish and the Drupal container |
| `{SERVICE_NAME}_internal` (bridge) | Varnish ↔ Drupal ↔ Redis (isolated per stack) |

Typical addressing on this deployment:

- `reverse-proxy`: e.g. `172.20.0.0/16` (Traefik, Varnish, Drupal each get an IP)
- `{SERVICE_NAME}_internal`: e.g. `192.168.64.0/20` (auto-assigned per stack; differs between instances)

Varnish talks to Drupal on the **internal** network (`wisski-production--drupal:80`), not via Traefik.

## Public URLs and Traefik routers

From `wisski-base-stack/docker-compose.yml`:

| Browser URL | Traefik router target | Use |
|-------------|----------------------|-----|
| `https://{instance}.wisski.{scs-subdomain}.{domain}` | `{SERVICE_NAME}--varnish:80` | Normal traffic (cached) |
| `https://raw.{instance}.wisski.{scs-subdomain}.{domain}` | `{SERVICE_NAME}--drupal:80` | Bypass Varnish (debug, health semantics) |

Traefik terminates TLS and sets `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`, and `X-Forwarded-Port` on the HTTP connection to the backend.

SCS Manager sets `DRUPAL_TRUSTED_HOSTS` to allow both hostnames (public and `raw.*`).

## Request path (production)

```mermaid
flowchart LR
  Client[Client browser]
  Traefik[Traefik scs--reverse-proxy]
  Varnish[Varnish container]
  Nginx[Nginx in drupal container]
  FPM[PHP-FPM Unix socket]
  Drupal[Drupal / WissKI]

  Client -->|HTTPS| Traefik
  Traefik -->|HTTP + X-Forwarded-*| Varnish
  Varnish -->|HTTP + X-Forwarded-*| Nginx
  Nginx -->|FastCGI| FPM
  FPM --> Drupal
```

### Raw bypass path

```mermaid
flowchart LR
  Client[Client browser]
  Traefik[Traefik]
  Nginx[Nginx in drupal container]
  FPM[PHP-FPM]
  Drupal[Drupal]

  Client -->|HTTPS| Traefik
  Traefik -->|HTTP + X-Forwarded-*| Nginx
  Nginx --> FPM
  FPM --> Drupal
```

## Who sees which IP and headers

Each hop only knows its **direct** TCP peer as `REMOTE_ADDR` (or Varnish `client.ip`):

| Hop | Connects to | `REMOTE_ADDR` at next hop (typical) | Relevant `X-Forwarded-*` |
|-----|-------------|-------------------------------------|----------------------------|
| Traefik | Client (TLS) | — | Sets all four from real client |
| Varnish | Traefik | Traefik IP on `reverse-proxy` | Forwards / appends `X-Forwarded-For`; keeps Proto/Host/Port |
| Nginx | Varnish (main path) | Varnish IP on `internal` network | Passes request headers to PHP |
| PHP-FPM | Nginx (Unix socket) | Nginx’s view of client = **Varnish IP** | `HTTP_X_FORWARDED_*` from Nginx |

For the **raw** path, PHP’s `REMOTE_ADDR` is the **Traefik** IP on `reverse-proxy`, not Varnish.

Drupal must trust the **direct HTTP peer of Nginx** (Varnish or Traefik), not the end-user IP. That is what `reverse_proxy_addresses` configures. With `DRUPAL_PROXY_ADDRESSES=auto`, the image detects the container’s network CIDRs on each boot.

See [Reverse proxy settings](../configs/reverse-proxy.md) and the [reverse proxy knowledge base](../../knowledge-base/reverse-proxy-backend-config-knowledge-base.md).

## Service configuration

Examples below use the live instance **`wisski-production`** on this deployment (`dev-scs.sammlungen.io`). Source repos: [wisski-base-stack](https://github.com/soda-collections-objects-data-literacy/wisski-base-stack) (compose + Traefik labels), [wisski-base-image](https://github.com/soda-collections-objects-data-literacy/wisski-base-image) (Nginx + Drupal entrypoint), [scs-varnish](https://github.com/soda-collections-objects-data-literacy/scs-varnish) (VCL baked into image).

### Traefik

WissKI stacks do **not** ship a Traefik config file. Routing is declared via **Docker labels** on the Varnish and Drupal containers. Traefik itself runs once as `scs--reverse-proxy` on the shared `reverse-proxy` network.

**Shared Traefik static config** (`docker-compose.yml` → `scs--reverse-proxy`):

```yaml
command:
  - --providers.docker
  - --providers.docker.exposedbydefault=false
  - --entrypoints.web.address=:80
  - --entrypoints.websecure.address=:443
  - --entrypoints.web.http.redirections.entryPoint.to=websecure
  - --entrypoints.web.http.redirections.entryPoint.scheme=https
  - --certificatesresolvers.le.acme.tlschallenge=true
  - --certificatesresolvers.le.acme.storage=/certificates/acme.json
```

**WissKI stack labels** (`wisski-base-stack/docker-compose.yml`, resolved for `wisski-production`):

```yaml
# Public URL → Varnish (cached)
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=reverse-proxy"
  - "traefik.http.routers.wisski-production--varnish.rule=Host(`wisski-production.wisski.dev-scs.sammlungen.io`)"
  - "traefik.http.routers.wisski-production--varnish.entrypoints=websecure"
  - "traefik.http.routers.wisski-production--varnish.tls=true"
  - "traefik.http.routers.wisski-production--varnish.tls.certresolver=le"
  - "traefik.http.services.wisski-production--varnish.loadbalancer.server.port=80"

# raw.* URL → Drupal/Nginx directly (bypass Varnish)
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=reverse-proxy"
  - "traefik.http.routers.wisski-production-drupal.rule=Host(`raw.wisski-production.wisski.dev-scs.sammlungen.io`)"
  - "traefik.http.routers.wisski-production-drupal.entrypoints=websecure"
  - "traefik.http.routers.wisski-production-drupal.tls=true"
  - "traefik.http.routers.wisski-production-drupal.tls.certresolver=le"
  - "traefik.http.services.wisski-production-drupal.loadbalancer.server.port=80"
```

Traefik terminates TLS on `websecure` (:443), obtains certificates via resolver `le`, and forwards plain HTTP to the backend with `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`, and `X-Forwarded-Port`.

**Container IPs on `reverse-proxy` (example):**

| Container | IP |
|-----------|-----|
| `scs--reverse-proxy` (Traefik) | `172.20.0.5` |
| `wisski-production--varnish` | `172.20.0.43` |
| `wisski-production--drupal` | `172.20.0.42` |

### Varnish

**Portainer / compose environment** (`wisski-base-stack/docker-compose.yml`):

```yaml
environment:
  - VARNISH_SIZE=512M
  - VARNISH_BACKEND_HOST=wisski-production--drupal
  - VARNISH_BACKEND_PORT=80
```

At container start the `scs-varnish` image substitutes `VARNISH_BACKEND_HOST` / `VARNISH_BACKEND_PORT` into `default.vcl`. **Live VCL** on `wisski-production--varnish`:

```vcl
vcl 4.1;

backend default {
    .host = "wisski-production--drupal";
    .port = "80";
    .connect_timeout = 5s;
    .first_byte_timeout = 60s;
    .between_bytes_timeout = 30s;
    .max_connections = 800;
}

acl purge {
    "172.18.0.0"/16;
    "172.19.0.0"/16;
    "127.0.0.1";
}

sub vcl_recv {
    # Traefik-safe: keep existing X-Forwarded-* from Traefik, append this hop to X-Forwarded-For
    if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
    } else {
        set req.http.X-Forwarded-For = client.ip;
    }
    if (!req.http.X-Forwarded-Proto) {
        set req.http.X-Forwarded-Proto = "http";
    }
    if (!req.http.X-Forwarded-Host) {
        set req.http.X-Forwarded-Host = req.http.Host;
    }
    if (!req.http.X-Forwarded-Port) {
        if (req.http.X-Forwarded-Proto == "https") {
            set req.http.X-Forwarded-Port = "443";
        } else {
            set req.http.X-Forwarded-Port = "80";
        }
    }

    # Pass admin, user, authenticated, non-GET/HEAD
    if (req.method != "GET" && req.method != "HEAD") { return (pass); }
    if (req.url ~ "^/(status|update|install)\.php$" ||
        req.url ~ "^/admin" || req.url ~ "^/user" ||
        req.url ~ "^/flag" || req.url ~ "^.*/(ajax|ahah)/") {
        return (pass);
    }
    if (req.http.Authorization || req.http.Cookie) { return (pass); }

    return (hash);
}
```

Varnish connects to Drupal on the **internal** network (`wisski-production--drupal:80` → `192.168.64.3`). From Nginx’s perspective, `REMOTE_ADDR` on the main path is Varnish (`192.168.64.4` on `wisski-production_internal`).

Full VCL also defines `vcl_backend_response` (TTL, grace), `vcl_deliver` (`X-Varnish-Cache: HIT|MISS`), and PURGE/BAN handling. See `scs-manager-stack/configs/varnish/default.vcl` in this repo for the complete template (same Traefik-safe header logic).

### Nginx

Nginx runs **inside** `wisski-production--drupal`. Config file: `wisski-base-image/config/nginx/drupal.conf`.

```nginx
server {
  listen 80 default_server;
  server_name _;
  root /opt/drupal/web;
  index index.php index.html;

  client_max_body_size 512m;

  location / {
    try_files $uri @drupal;
  }

  location @drupal {
    rewrite ^/(.*)$ /index.php?q=$1 last;
  }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    fastcgi_param DOCUMENT_ROOT $realpath_root;
    fastcgi_index index.php;
    fastcgi_pass unix:/run/php/php-fpm.sock;
    fastcgi_read_timeout 300;
  }

  error_page 404 /index.php;
}
```

`fastcgi_params` passes incoming request headers to PHP unchanged — including `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`, and `X-Forwarded-Port` from Varnish or Traefik.

**Access log format** (`wisski-base-image/config/nginx/nginx.conf`) logs the forwarded chain:

```nginx
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';
```

On the main path `$remote_addr` is the Varnish IP (`192.168.64.4`); `$http_x_forwarded_for` contains the client and Traefik hops.

**Health check** (compose): `curl -fsS -H "Host: wisski-production.wisski.dev-scs.sammlungen.io" http://localhost/health`

### Drupal settings (`settings.php`)

The wisski-base-image **entrypoint** appends blocks to `/opt/drupal/web/sites/default/settings.php` on first install and syncs reverse proxy on every boot. **Portainer env** (excerpt for `wisski-production`):

```env
SERVICE_NAME=wisski-production
DRUPAL_DOMAIN=wisski-production.wisski.dev-scs.sammlungen.io
DRUPAL_TRUSTED_HOSTS=^wisski-production\.wisski\.dev-scs\.sammlungen\.io$|^raw\.wisski-production\.wisski\.dev-scs\.sammlungen\.io$
DRUPAL_PRIVATE_FILES_DIR=/opt/drupal/private-files
DRUPAL_PROXY_ADDRESSES=auto
REDIS_HOST=redis
REDIS_PORT=6379
DB_HOST=scs--database
DB_NAME=sql-production
```

**Resulting `settings.php` snippets** (from a correctly configured instance with `DRUPAL_PROXY_ADDRESSES=auto`):

```php
$settings['trusted_host_patterns'] = [
  "^wisski-production\\.wisski\\.dev-scs\\.sammlungen\\.io$",
  "^raw\\.wisski-production\\.wisski\\.dev-scs\\.sammlungen\\.io$",
];

$settings["file_private_path"] = "/opt/drupal/private-files";

/**
 * Redis cache backend configuration.
 * Auto-configured by entrypoint.
 */
if (file_exists('/var/configs/redis.settings.php')) {
  include '/var/configs/redis.settings.php';
}

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

The `reverse_proxy_addresses` values come from `ip -o -4 addr show scope global` on the Drupal container (`eth0` = `reverse-proxy`, `eth1` = internal stack network). They must include the CIDR of whoever connects to Nginx:80 — Varnish on the main URL and Traefik on `raw.*`.

**Legacy misconfiguration on this server:** stacks created before `DRUPAL_PROXY_ADDRESSES=auto` may still have:

```php
$settings['reverse_proxy_addresses'] = ["172.18.0.0/16", "172.19.0.0/16"];
```

Those CIDRs do not match the live `reverse-proxy` network (`172.20.0.0/16`), so Drupal ignores `X-Forwarded-*` and emits `http://` URLs. Fix: set `DRUPAL_PROXY_ADDRESSES=auto` in Portainer and recreate the Drupal container (or set explicit `172.20.0.0/16|192.168.64.0/20`).

Per-snippet details: [configs/](../configs/index.md).

## SCS Manager integration

When SCS Manager creates a WissKI stack via Portainer:

1. Clones `wisski-base-stack` (branch/tag from component version or development settings)
2. Injects environment variables (domain, DB, Keycloak, `DRUPAL_PROXY_ADDRESSES`, …)
3. Default **Drupal reverse proxy addresses** in SCS Manager settings: `auto` → Portainer env `DRUPAL_PROXY_ADDRESSES=auto`

Configure at: `/admin/config/soda-scs-manager/settings` → **WissKI** → **Drupal reverse proxy addresses**.

Existing stacks keep their Portainer env until updated; changing SCS Manager settings alone does not rewrite running stacks.

## Standalone use (without Traefik)

For local development with [dockerWissKI](https://github.com/soda-collections-objects-data-literacy/dockerWissKI) (no Traefik):

- Set `DRUPAL_PROXY_ADDRESSES=none`
- Access via published ports (`:80` Drupal, `:8000` Varnish)
- No TLS termination; Drupal uses direct `Host` and `http` scheme

The same `wisski-base-image` supports both modes; only env and compose routing differ.

## Related documentation

- [WissKI Drupal `settings.php` snippets](../configs/index.md) — what the entrypoint writes into `settings.php`
- [Reverse proxy knowledge base](../../knowledge-base/reverse-proxy-backend-config-knowledge-base.md)
- [Post-configuration checklist](../../post-configuration/checklist.md) — WissKI proxy and Portainer steps
