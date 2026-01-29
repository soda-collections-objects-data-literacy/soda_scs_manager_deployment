# Troubleshooting

Common issues and testing procedures for the SODa SCS Manager deployment.

## Verification Scripts

The `docs/troubleshooting/` directory contains test scripts to verify your deployment:

### Test Proxy Client IP Forwarding

**Purpose:** Verify that Traefik is correctly forwarding real client IP addresses to backend services.

**Script:** `test-proxy-client-ips.bash`

**Usage:**
```bash
./docs/troubleshooting/test-proxy-client-ips.bash [domain]
# Default domain: echo.scs.sammlungen.io
```

**What it checks:**
- Real IPv4 client IPs are preserved in X-Forwarded-For and X-Real-Ip headers
- Real IPv6 client IPs are preserved (if available)
- Docker internal IPs are not being used instead of real client IPs

**Expected result:** Both IPv4 and IPv6 tests should show your real public IP addresses, not Docker internal IPs like `172.x.x.x`.

**Related documentation:** [Reverse proxy backend config](../reverse-proxy-backend-config-knowledge-base.md)

### Test Nextcloud .well-known URLs

**Purpose:** Verify that Nextcloud's .well-known URLs for CalDAV, CardDAV, webfinger, and nodeinfo are working correctly.

**Script:** `test-nextcloud-wellknown.bash`

**Usage:**
```bash
./docs/troubleshooting/test-nextcloud-wellknown.bash [domain]
# Default domain: drive.scs.localhost
```

**What it checks:**
- `.well-known/carddav` redirects correctly
- `.well-known/caldav` redirects correctly
- `.well-known/webfinger` redirects correctly
- `.well-known/nodeinfo` redirects correctly

**Expected result:** All URLs should return HTTP 301, 302, or 200 status codes.

**Related documentation:** [Nextcloud warnings](nextcloud-warnings.md)

## Common Issues

### Reverse Proxy / Client IP Issues

**Symptom:** Backend services see Docker gateway IPs (172.x.x.x) instead of real client IPs in logs or access controls.

**Causes:**
1. Incorrect Traefik port binding configuration
2. Missing or incorrect backend proxy configuration
3. Upstream proxy without proper trusted IPs configuration

**Solutions:**
1. Run the `test-proxy-client-ips.bash` script to verify current behavior
2. Check network configuration - IPv6 must be enabled:
   ```bash
   docker network inspect reverse-proxy --format '{{.EnableIPv6}}'
   # Should return: true
   ```
   If false, see [Network creation guide](../initial-setup/network-creation.md) for detailed instructions on recreating the network with IPv6.
3. Check Traefik port bindings in `docker-compose.yml` (should be standard `- "80:80"` and `- "443:443"`)
4. Verify backend configurations:
   - Drupal: Check `00_custom_configs/scs-manager-stack/drupal/reverse-proxy.settings.php`
   - Keycloak: Check `KC_PROXY_HEADERS=xforwarded` in environment
   - Nextcloud: Check `OVERWRITEPROTOCOL=https` and `OVERWRITEHOST` in environment
5. See [Reverse proxy backend config](../reverse-proxy-backend-config-knowledge-base.md) for detailed configuration

### Nextcloud Warnings

See [Nextcloud warnings](nextcloud-warnings.md) for common Nextcloud admin panel warnings and how to resolve them.
