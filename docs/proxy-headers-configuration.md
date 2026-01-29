# Proxy Headers Configuration for Traefik and Keycloak

## Date
2026-01-29

## Problem Statement

When running Keycloak behind a reverse proxy (Traefik), the application needs to correctly understand that it's being accessed via HTTPS even though Traefik communicates with it over HTTP internally. Without proper proxy header configuration, Keycloak will generate incorrect redirect URLs (using HTTP instead of HTTPS), breaking OAuth flows and causing security issues.

## What Was Checked

### 1. Traefik Configuration (docker-compose.yml)

**Location:** `/var/deploy/soda_scs_manager_deployment/docker-compose.yml`

#### Checked:
- Whether `forwardedHeaders.trustedIPs` was configured for entrypoints
- Where the configuration was placed (labels vs command section)
- The running Traefik process arguments

#### Findings:
```yaml
# WRONG - These were in the labels section (lines 219-220)
labels:
  - --entrypoints.web.forwardedHeaders.trustedIPs=172.18.0.0/16
  - --entrypoints.websecure.forwardedHeaders.trustedIPs=172.18.0.0/16
```

**Issue:** Command-line arguments in the labels section are ignored. They must be in the `command` section.

**Verification Command:**
```bash
docker exec scs--reverse-proxy ps aux | grep traefik
```

The output showed the configuration was NOT applied in the running process.

### 2. Keycloak Configuration

**Location:** `/var/deploy/soda_scs_manager_deployment/keycloak/docker-compose.yml` and `docker-compose.override.yml`

#### Checked:
- Proxy mode settings (`KC_PROXY` vs `KC_PROXY_HEADERS`)
- Hostname configuration format
- Environment variable merge behavior

#### Findings:

**Base config (docker-compose.yml):**
```yaml
environment:
  KC_PROXY: edge  # Deprecated in Keycloak 26
```

**Override config (docker-compose.override.yml):**
```yaml
environment:
  KC_HOSTNAME: https://${KC_DOMAIN}  # Wrong - includes protocol
  KC_PROXY_HEADERS: xforwarded  # Correct but conflicting with base
```

**Issues:**
1. **Conflicting proxy settings:** Both `KC_PROXY: edge` (deprecated) and `KC_PROXY_HEADERS: xforwarded` were set
2. **Incorrect hostname format:** Hostname included protocol `https://`
3. **Merge behavior:** Environment variables were merging, not replacing

**Verification Commands:**
```bash
# Check environment variables in container
docker exec keycloak--keycloak env | grep -E "KC_PROXY|KC_HOSTNAME|KC_HTTP"

# Check runtime configuration
docker exec keycloak--keycloak /opt/keycloak/bin/kc.sh show-config 2>&1 | grep -E "proxy|hostname|http-enabled"
```

### 3. Network Configuration

**Checked:**
- Docker network range (`reverse-proxy` network)
- Container IP addresses
- Traefik's trusted IP range matches actual network

**Verification Commands:**
```bash
# Check Keycloak IP
docker inspect keycloak--keycloak --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# Check network range
docker network inspect reverse-proxy
```

**Finding:** Network is `172.18.0.0/16`, which matches the configured trusted IPs.

### 4. End-to-End Proxy Header Flow

**Test Method:**
```bash
# Simulate Traefik sending X-Forwarded headers to Keycloak
docker exec scs--reverse-proxy wget -q -O - \
  http://172.18.0.3:8080/realms/scs/.well-known/openid-configuration \
  --header="X-Forwarded-Proto: https" \
  --header="X-Forwarded-Host: auth.scs.sammlungen.io" \
  --header="X-Forwarded-For: 1.2.3.4"
```

**Before fix:** Not tested (configuration was broken)
**After fix:** Keycloak returned correct HTTPS URLs

## What Was Fixed

### 1. Traefik Configuration

**File:** `docker-compose.yml`

**Change:** Moved `forwardedHeaders.trustedIPs` from labels to command section.

```yaml
# BEFORE (lines 218-220 in labels section)
labels:
  - "traefik.http.routers.scs-manager-redirect.tls.certresolver=le"
  # Trust X-Forwarded-* headers only from internal Docker network
  - --entrypoints.web.forwardedHeaders.trustedIPs=172.18.0.0/16
  - --entrypoints.websecure.forwardedHeaders.trustedIPs=172.18.0.0/16

# AFTER (removed from labels, added to command section)
command:
  - --providers.docker
  - --entrypoints.web.address=:80
  - --entrypoints.websecure.address=:443
  # Trust X-Forwarded-* headers only from internal Docker network
  - --entrypoints.web.forwardedHeaders.trustedIPs=172.18.0.0/16
  - --entrypoints.websecure.forwardedHeaders.trustedIPs=172.18.0.0/16
```

### 2. Keycloak Configuration

**File:** `keycloak/docker-compose.override.yml`

**Change:** Added `!override` tag and fixed environment variables.

```yaml
# BEFORE
environment:
  KC_DB_URL: jdbc:${KC_DB_DRIVER:-mariadb}://scs--database:3306/${KC_DB_NAME:-keycloak}
  KC_HOSTNAME: https://${KC_DOMAIN}  # Wrong format
  KC_HTTP_ENABLED: "true"
  KC_PROXY_HEADERS: xforwarded
  KC_CACHE: local
  # Missing: DB credentials, admin credentials
  # Merging with base config which had KC_PROXY: edge

# AFTER
environment: !override
  # Database connection - use parent stack's database.
  KC_DB_URL: jdbc:${KC_DB_DRIVER:-mariadb}://scs--database:3306/${KC_DB_NAME:-keycloak}
  KC_DB_USERNAME: ${KC_DB_USERNAME}
  KC_DB_PASSWORD: ${KC_DB_PASSWORD}

  # Initial admin password.
  KC_BOOTSTRAP_ADMIN_USERNAME: ${KC_BOOTSTRAP_ADMIN_USERNAME}
  KC_BOOTSTRAP_ADMIN_PASSWORD: ${KC_BOOTSTRAP_ADMIN_PASSWORD}

  # Public hostname (no protocol, just domain).
  KC_HOSTNAME: ${KC_DOMAIN}
  KC_HOSTNAME_STRICT: "true"

  # Proxy configuration for Traefik.
  KC_HTTP_ENABLED: "true"
  KC_PROXY_HEADERS: xforwarded

  # Use local cache for single-node deployment.
  KC_CACHE: local
```

**Key changes:**
1. Added `!override` to completely replace environment variables (not merge)
2. Fixed `KC_HOSTNAME` to exclude protocol
3. Added `KC_HOSTNAME_STRICT: "true"` for security
4. Included all required variables from base config
5. Removed conflicting `KC_PROXY: edge` by using override

## Why This Is Important

### 1. Security

**Without proper proxy headers:**
- Keycloak generates HTTP URLs instead of HTTPS
- Browsers reject mixed content (HTTPS page loading HTTP resources)
- OAuth tokens and credentials could be transmitted over unencrypted connections
- Session cookies might not have the `Secure` flag set correctly

### 2. OAuth/OIDC Flows

**Redirect URIs must match exactly:**
```
Client expects: https://auth.scs.sammlungen.io/realms/scs/protocol/openid-connect/auth
Keycloak returns: http://auth.scs.sammlungen.io/...  # Without proper headers
Result: OAuth flow fails with "redirect_uri mismatch" error
```

### 3. Keycloak-Specific Requirements

**Keycloak 26 requires explicit proxy header configuration:**
- Old method: `KC_PROXY: edge` (deprecated, less secure)
- New method: `KC_PROXY_HEADERS: xforwarded` (explicit, more secure)
- Must be combined with `KC_HOSTNAME` and `KC_HOSTNAME_STRICT`

### 4. Traefik Trust Model

**Why `trustedIPs` is critical:**
```
Internet → Traefik (public IP) → Keycloak (internal IP)
```

Without `trustedIPs` configuration:
- Traefik doesn't trust X-Forwarded headers from any source
- Malicious clients could inject fake X-Forwarded headers
- Applications wouldn't know the real client IP or protocol

With proper configuration:
- Traefik only trusts headers from Docker network (172.18.0.0/16)
- External headers are stripped and replaced
- Backend applications receive accurate proxy information

### 5. Production Best Practices

**This configuration ensures:**
1. **Correct URL generation:** All Keycloak URLs use HTTPS
2. **Proper client IP logging:** Real client IPs are preserved via X-Forwarded-For
3. **Security compliance:** HSTS, secure cookies, and HTTPS redirects work correctly
4. **Integration compatibility:** External services using OAuth can connect properly

## Verification Checklist

After applying these fixes, verify:

```bash
# 1. Traefik has trustedIPs in running config
docker exec scs--reverse-proxy ps aux | grep trustedIPs

# 2. Keycloak environment is correct
docker exec keycloak--keycloak env | grep -E "KC_PROXY|KC_HOSTNAME"

# 3. Keycloak runtime config is correct
docker exec keycloak--keycloak /opt/keycloak/bin/kc.sh show-config 2>&1 | grep -E "proxy-headers|hostname-strict"

# 4. End-to-end test returns HTTPS URLs
docker exec scs--reverse-proxy wget -q -O - \
  http://172.18.0.3:8080/realms/scs/.well-known/openid-configuration \
  --header="X-Forwarded-Proto: https" \
  --header="X-Forwarded-Host: auth.scs.sammlungen.io" | grep "https://auth"
```

## Expected Results

All URLs in Keycloak responses should use HTTPS:
```json
{
  "issuer": "https://auth.scs.sammlungen.io/realms/scs",
  "authorization_endpoint": "https://auth.scs.sammlungen.io/realms/scs/protocol/openid-connect/auth",
  "token_endpoint": "https://auth.scs.sammlungen.io/realms/scs/protocol/openid-connect/token"
}
```

## Related Documentation

- [Keycloak Reverse Proxy Guide](https://www.keycloak.org/server/reverseproxy)
- [Traefik ForwardedHeaders](https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers)
- [Docker Compose Override](https://docs.docker.com/compose/multiple-compose-files/merge/)

## Common Pitfalls to Avoid

1. **Never put command arguments in labels section** - They are silently ignored
2. **Don't include protocol in `KC_HOSTNAME`** - Use `auth.example.com`, not `https://auth.example.com`
3. **Use `!override` when you need complete replacement** - Docker Compose merges by default
4. **Match `trustedIPs` to your actual network** - Check with `docker network inspect`
5. **Keep Keycloak proxy settings in sync with Traefik** - Both must agree on header handling
