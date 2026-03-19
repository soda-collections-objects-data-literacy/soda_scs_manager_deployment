# DBMS/phpMyAdmin SSO Troubleshooting

## Env vars not set (manager.localhost, auth.localhost, etc.)

If logout redirects to `manager.localhost` or Keycloak uses `auth.localhost`, the phpMyAdmin container is not receiving env vars from the main `docker-compose.yml`.

**Cause:** `scs--phpmyadmin` is defined only in the **main** `docker-compose.yml` at the repo root. If that file is not in your `COMPOSE_FILE`, or you run from a different directory, the service may use a different compose definition without the env vars.

**Fix:**
1. Ensure `COMPOSE_FILE` has the main `docker-compose.yml` **first**:
   ```
   COMPOSE_FILE=docker-compose.yml:jupyterhub/docker-compose.yml:...
   ```
2. Run `docker compose` from the repo root (where the main `docker-compose.yml` lives).
3. **Recreate** the container (restart does not pick up new env):
   ```bash
   docker compose up -d scs--phpmyadmin
   ```
4. Verify env in the container:
   ```bash
   docker exec scs--phpmyadmin env | grep -E 'KC_|SCS_DBMS|SCS_MANAGER'
   ```

**Fallback:** The config derives the manager URL from `HTTP_HOST` (dbms.X → manager.X), so it should work even without env if you visit phpMyAdmin at the correct host (e.g. dbms.dev-scs.sammlungen.io).

---

## ERR_CONNECTION_REFUSED on logout

When clicking "Log out" in phpMyAdmin, the browser redirects to Keycloak's logout URL. If you see **ERR_CONNECTION_REFUSED**, the browser cannot reach the Keycloak host.

**Cause:** The logout URL is built from `KC_URL` (or `KC_DOMAIN`). If that host is not reachable from your browser (e.g. internal hostname, wrong domain), the connection fails.

**Fix:**
1. Ensure `.env` has the correct Keycloak URL and realm (same as forward-auth):
   - `KC_URL=https://auth.dev-scs.sammlungen.io` (or `KC_DOMAIN=auth.dev-scs.sammlungen.io`)
   - `KC_REALM=dev-scs` (must match your Keycloak realm)
   - `SCS_DBMS_DOMAIN=dbms.dev-scs.sammlungen.io` (must match the phpMyAdmin host)
2. If `KC_URL`/`KC_DOMAIN` are unset, the URL is built from `KC_SERVICE_NAME.SCS_SUBDOMAIN.SCS_BASE_DOMAIN` (e.g. auth.dev-scs.sammlungen.io)
3. Restart phpMyAdmin: `docker compose restart scs--phpmyadmin`

---

## ERR_TOO_MANY_REDIRECTS

This error can occur when:
1. The forward-auth OAuth flow gets stuck between Keycloak and the DBMS domain.
2. Connection failure loop: wrong MariaDB password or user doesn't exist. **Fix:** signon.php tests the connection before redirecting; on failure it shows "Connection failed" instead of looping. Edit a project with SQL components in SCS Manager to sync your password.

## Cause

The forward-auth logs show "Handling callback" followed by "sending CSRF cookie and a redirect to OIDC login". That means the **OAuth token exchange fails** after Keycloak redirects back to `/_oauth`. Forward-auth then redirects to Keycloak again; Keycloak (user already logged in) immediately redirects back to `/_oauth`. Loop.

**Keycloak logs** show `LOGIN_ERROR` with `error="invalid_user_credentials"` for the DBMS client — this usually means the **client secret is wrong** (Keycloak uses this error for client auth failure).

## Fixes

### 1. Verify `SCS_DBMS_CLIENT_SECRET`

The client secret in `.env` must **exactly match** the Keycloak client secret.

1. Keycloak Admin → **Clients** → **DBMS SSO** (client ID: `https://${SCS_DBMS_DOMAIN}`)
2. **Credentials** tab → copy the secret
3. Set `.env`: `SCS_DBMS_CLIENT_SECRET=<paste>`
4. Restart: `docker compose restart scs--forward-auth`

### 2. Re-run Keycloak pre-install

If the realm was imported before `SCS_DBMS_*` was set, the client may have wrong secret or redirect URI:

```bash
./01_scripts/keycloak/pre-install.sh
docker compose restart keycloak--keycloak
```

### 3. Check redirect URI in Keycloak

The client must have:

- **Valid redirect URIs**: `https://${SCS_DBMS_DOMAIN}/_oauth`
- **Web origins**: `https://${SCS_DBMS_DOMAIN}`

No trailing slash on `/_oauth`.

### 4. Clear browser cookies

After fixing the secret, clear cookies for `dbms.dev-scs.sammlungen.io` (or your domain) and try again.

## Debug

```bash
# Forward-auth logs (look for "Handling callback" vs "sending CSRF")
docker logs scs--forward-auth --tail 50

# Traefik/Keycloak: 400 on token = wrong secret or redirect_uri
docker logs scs--reverse-proxy --tail 100 | grep -E "token|401|400"
```
