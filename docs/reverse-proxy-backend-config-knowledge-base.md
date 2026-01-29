# Reverse proxy: frontend (Traefik) and backend config (knowledge base)
## Overview
HTTPS is terminated at Traefik; backends receive HTTP. Traefik automatically creates X-Forwarded-Proto, X-Forwarded-Host, X-Forwarded-For, X-Forwarded-Port headers from the actual client connection. Each backend must be configured to trust and use those headers (or equivalent overwrite settings).
## Traefik (frontend)
**Role:** Terminate TLS, forward HTTP to backends, automatically create X-Forwarded-* headers from the real client connection.
**Where:** `docker-compose.yml` → `scs--reverse-proxy` → `ports` and `command` (not labels; labels are for routers/services).

**Port binding configuration**
Real client IP addresses are preserved with the current configuration:
```yaml
ports:
  - "80:80"
  - "443:443"
```

**Current working setup:** The deployment successfully preserves real client IPs for both IPv4 and IPv6 connections using the standard short-form port syntax. This works correctly when:
- The Docker network has IPv6 enabled (`enable_ipv6: true`)
- Traefik is configured as the edge proxy (no upstream proxy)
- The network driver is set to `bridge`

**Required network configuration:**
```yaml
networks:
  reverse-proxy:
    name: reverse-proxy
    enable_ipv6: true
    driver: bridge
```

The `enable_ipv6: true` setting is critical for preserving real client IPs with the standard port binding syntax. Without IPv6 enabled, you may need to use `mode: host` explicitly.

**Network creation command:**
```bash
docker network create reverse-proxy --driver bridge --ipv6
```

For detailed network creation information, troubleshooting, and reverse engineering details, see the [Network creation guide](initial-setup/network-creation.md).

**Alternative (explicit) configuration:** For maximum compatibility across different Docker versions and network configurations, you can use the long-form syntax with `mode: host`:
```yaml
ports:
  - target: 80
    published: 80
    protocol: tcp
    mode: host          # Explicitly bypasses docker-proxy
  - target: 443
    published: 443
    protocol: tcp
    mode: host          # Explicitly bypasses docker-proxy
```

**Note:** The `mode: host` approach explicitly bypasses Docker's NAT layer but may have compatibility considerations with IPv6 and certain network setups. The current short-form configuration is validated and working correctly for this deployment.

**Command configuration (when Traefik is the edge proxy):**
```yaml
command:
  - --entrypoints.web.address=:80
  - --entrypoints.websecure.address=:443
  # No forwardedHeaders configuration needed - Traefik creates headers automatically
```

**Note:** `forwardedHeaders.trustedIPs` is ONLY needed if Traefik is behind another proxy. When Traefik is the edge proxy (first contact with clients), it automatically creates accurate X-Forwarded-* headers and you should NOT configure trustedIPs.
## Drupal (backend)
**Role:** Trust the reverse proxy and use X-Forwarded-* for scheme, host, port and client IP so generated URLs and logging are correct.
**Where:** `00_custom_configs/scs-manager-stack/drupal/reverse-proxy.settings.php` (included from Drupal's `settings.php`).
**Required config:**
```php
$settings['reverse_proxy'] = TRUE;
$settings['reverse_proxy_addresses'] = ['172.18.0.0/16', '172.19.0.0/16'];
$settings['reverse_proxy_trusted_headers'] = \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO;
```
**Meaning:** Only requests from those IPs (Traefik/Varnish) are treated as coming from a reverse proxy; Drupal then uses the X-Forwarded-* headers for scheme, host, port and client IP.
## Varnish (backend)
**Role:** Sits between Traefik and Drupal. Receives HTTP from Traefik with X-Forwarded-* already selt. Must pass them through to Drupal and only add/complete them when missing (e.g. append Varnish IP to X-Forwarded-For).
**Where:** `00_custom_configs/scs-manager-stack/varnish/default.vcl.tpl` → `vcl_recv`.
**Required pattern (Traefik-safe):**
```vcl
# X-Forwarded-For: append Varnish IP if Traefik already set it
if (req.http.X-Forwarded-For) {
    set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
} else {
    set req.http.X-Forwarded-For = client.ip;
}
# X-Forwarded-Proto: trust Traefik; default only if missing
if (!req.http.X-Forwarded-Proto) {
    set req.http.X-Forwarded-Proto = "http";
}
# X-Forwarded-Host / X-Forwarded-Port: pass through, set from Host/Proto if missing
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
```
**Meaning:** Varnish does not overwrite Traefik's X-Forwarded-Proto/Host/Port; it only fills defaults when absent so Drupal still sees the original scheme and host.
## Nextcloud (backend)
**Role:** Generate HTTPS URLs and accept requests for the public hostname. Nextcloud is behind Traefik (and in this stack often behind an internal nginx reverse-proxy container); it does not use X-Forwarded-* by default for URL generation unless overwrite is set.
**Where:** `scs-nextcloud-stack/docker-compose.yml` → `nextcloud--nextcloud` → `environment`.
**Required config:**
```yaml
environment:
  - OVERWRITEHOST=${NEXTCLOUD_NEXTCLOUD_DOMAIN}
  - OVERWRITEPROTOCOL=https
  - NEXTCLOUD_TRUSTED_DOMAINS=localhost ${NEXTCLOUD_NEXTCLOUD_DOMAIN} ${NEXTCLOUD_ONLYOFFICE_DOMAIN} nextcloud--nextcloud-reverse-proxy
```
**Meaning:** OVERWRITEHOST forces the canonical host for URLs; OVERWRITEPROTOCOL forces https; NEXTCLOUD_TRUSTED_DOMAINS lists allowed Host values. No need to trust proxy IPs for URL building when overwrite is used; trusted_domains still control which Host headers are accepted.
## Keycloak (backend)
**Role:** Generate correct HTTPS redirect URIs for OAuth/OIDC and trust the proxy. Keycloak must use X-Forwarded-* (via proxy headers mode) and know its public hostname without protocol.
**Where:** `keycloak/docker-compose.override.yml` → `keycloak` → `environment` (use `environment: !override` so base env is fully replaced).
**Required config:**
```yaml
environment: !override
  KC_HOSTNAME: ${KC_DOMAIN}
  KC_HOSTNAME_STRICT: "true"
  KC_HTTP_ENABLED: "true"
  KC_PROXY_HEADERS: xforwarded
  KC_PROXY_TRUSTED_ADDRESSES: 172.16.0.0/12,192.168.0.0/16
  # ... DB, admin, cache, etc.
```
**Meaning:** 
- `KC_HOSTNAME` is the public hostname only (e.g. `auth.example.com`), no `https://`
- `KC_PROXY_HEADERS=xforwarded` makes Keycloak read X-Forwarded-* headers for URL building and client IP logging
- `KC_PROXY_TRUSTED_ADDRESSES` specifies which proxy IPs to trust (Docker networks)
- `KC_HTTP_ENABLED=true` allows HTTP between Traefik and Keycloak
- `KC_HOSTNAME_STRICT` restricts redirects to that hostname

**Pitfalls:** Do not set KC_HOSTNAME to `https://...`; KC_PROXY (deprecated) should not be used in Keycloak 26+.
## Verification
To verify that real client IPs are being forwarded correctly, use the `scs--echo` service (whoami container):

**Test from external source:**
```bash
curl https://echo.scs.sammlungen.io
```

**Expected output should include:**
```
X-Forwarded-For: <your-real-public-ip>
X-Real-Ip: <your-real-public-ip>
```

**What to check:**
- `X-Forwarded-For` contains your real public IP (not a Docker gateway IP like `172.x.x.x`)
- `X-Real-Ip` matches your real public IP
- Works for both IPv4 and IPv6 connections

**Validation results (2026-01-29):**
- ✅ IPv4: Real client IPs correctly forwarded (e.g., `37.27.64.184`)
- ✅ IPv6: Real client IPs correctly forwarded (e.g., `2a01:4f9:3081:3204::2`)
- ✅ No docker-proxy processes interfering with port bindings
- ✅ Traefik automatically creates accurate X-Forwarded-* headers
- ✅ Network configuration: IPv6 enabled on `reverse-proxy` network

**Verify network configuration:**
```bash
docker network inspect reverse-proxy --format '{{.EnableIPv6}}'
# Should return: true
```

## Summary
| Component | What to set |
|-----------|-------------|
| Docker Network | **REQUIRED:** Enable IPv6 on the `reverse-proxy` network: `enable_ipv6: true` and `driver: bridge`. This is critical for the standard port binding syntax to preserve real client IPs. |
| Traefik (edge) | Standard port bindings (`- "80:80"`, `- "443:443"`) preserve real client IPs correctly with IPv6-enabled bridge networks. No `forwardedHeaders` config needed - automatically creates X-Forwarded-* headers. Only use `forwardedHeaders.trustedIPs` if behind another proxy. Alternative: Use `mode: host` for explicit docker-proxy bypass. |
| Drupal | `reverse_proxy`, `reverse_proxy_addresses`, `reverse_proxy_trusted_headers` in settings |
| Varnish | In vcl_recv: pass through X-Forwarded-* from Traefik, only set defaults when missing; append to X-Forwarded-For |
| Nextcloud | `OVERWRITEPROTOCOL=https`, `OVERWRITEHOST=<domain>`, `NEXTCLOUD_TRUSTED_DOMAINS` |
| Keycloak | `KC_PROXY_HEADERS=xforwarded`, `KC_PROXY_TRUSTED_ADDRESSES=<Docker networks>`, `KC_HOSTNAME=<domain>` (no protocol), `KC_HTTP_ENABLED=true`, `KC_HOSTNAME_STRICT=true` |
