# Reverse proxy: frontend (Traefik) and backend config (knowledge base)
## Overview
HTTPS is terminated at Traefik; backends receive HTTP. Traefik sends X-Forwarded-Proto, X-Forwarded-Host, X-Forwarded-For, X-Forwarded-Port so backends can generate correct URLs and log client IPs. Traefik must trust forwarded headers only from internal IPs (trustedIPs). Each backend must be configured to trust and use those headers (or equivalent overwrite settings).
## Traefik (frontend)
**Role:** Terminate TLS, forward HTTP to backends, add X-Forwarded-* headers. Trust forwarded headers only from the Docker network so external clients cannot spoof them.
**Where:** `docker-compose.yml` → `scs--reverse-proxy` → `command` (not labels; labels are for routers/services).
**Required config:**
```yaml
command:
  - --entrypoints.web.address=:80
  - --entrypoints.websecure.address=:443
  # Trust X-Forwarded-* headers only from internal Docker network
  - --entrypoints.web.forwardedHeaders.trustedIPs=172.18.0.0/16
  - --entrypoints.websecure.forwardedHeaders.trustedIPs=172.18.0.0/16
```
**Note:** Use your actual Docker network CIDR (e.g. `docker network inspect reverse-proxy`). If Traefik is behind another proxy, add that proxy’s IP/CIDR to trustedIPs.
## Drupal (backend)
**Role:** Trust the reverse proxy and use X-Forwarded-* for scheme, host, port and client IP so generated URLs and logging are correct.
**Where:** `00_custom_configs/scs-manager-stack/drupal/reverse-proxy.settings.php` (included from Drupal’s `settings.php`).
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
**Meaning:** Varnish does not overwrite Traefik’s X-Forwarded-Proto/Host/Port; it only fills defaults when absent so Drupal still sees the original scheme and host.
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
**Where:** `keycloak/docker-compose.override.yml` → `keycloak` → `environment` (use `environment: !override` so base env is fully replaced and KC_PROXY is not merged).
**Required config:**
```yaml
environment: !override
  KC_HOSTNAME: ${KC_DOMAIN}
  KC_HOSTNAME_STRICT: "true"
  KC_HTTP_ENABLED: "true"
  KC_PROXY_HEADERS: xforwarded
  # ... DB, admin, cache, etc.
```
**Meaning:** KC_HOSTNAME is the public hostname only (e.g. `auth.example.com`), no `https://`. KC_PROXY_HEADERS=xforwarded makes Keycloak use X-Forwarded-Proto/Host/For/Port for URL building and client IP. KC_HTTP_ENABLED=true allows HTTP between Traefik and Keycloak; KC_HOSTNAME_STRICT restricts redirects to that hostname.
**Pitfalls:** Do not set KC_HOSTNAME to `https://...`; do not leave KC_PROXY (deprecated) set when using KC_PROXY_HEADERS.
## Summary
| Component | What to set |
|-----------|-------------|
| Traefik | `--entrypoints.web.forwardedHeaders.trustedIPs` and `--entrypoints.websecure.forwardedHeaders.trustedIPs` (in command) |
| Drupal | `reverse_proxy`, `reverse_proxy_addresses`, `reverse_proxy_trusted_headers` in settings |
| Varnish | In vcl_recv: pass through X-Forwarded-* from Traefik, only set defaults when missing; append to X-Forwarded-For |
| Nextcloud | `OVERWRITEPROTOCOL=https`, `OVERWRITEHOST=<domain>`, `NEXTCLOUD_TRUSTED_DOMAINS` |
| Keycloak | `KC_PROXY_HEADERS=xforwarded`, `KC_HOSTNAME=<domain>` (no protocol), `KC_HTTP_ENABLED=true`, `KC_HOSTNAME_STRICT=true` |
