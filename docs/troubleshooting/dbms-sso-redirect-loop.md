# DBMS/phpMyAdmin SSO: ERR_TOO_MANY_REDIRECTS

This error occurs when the forward-auth flow gets stuck in a redirect loop between Keycloak and the DBMS domain.

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
