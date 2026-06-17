# Keycloak and Nextcloud Integration

This guide explains how to configure Keycloak and Nextcloud to work together for Single Sign-On (SSO) and cross-service authentication. The setup supports:

- **Web login**: Users log in to Nextcloud via Keycloak (Social Login app).
- **Bearer token validation**: API requests with OIDC Bearer tokens from SCS Manager are accepted by Nextcloud (user_oidc app).
- **App password creation**: SCS Manager can create Nextcloud app passwords on behalf of users for WebDAV integration (e.g. WissKI instances).

---

## Architecture Overview

```
┌─────────────────┐     OIDC Auth      ┌──────────────┐
│  SCS Manager    │ ◄────────────────► │   Keycloak   │
│  (Drupal)       │                    │   (IdP)      │
└────────┬────────┘                    └──────┬───────┘
         │                                    │
         │ Bearer token (aud includes          │ OIDC Auth
         │ Nextcloud client ID)                │
         ▼                                    ▼
┌─────────────────┐                    ┌──────────────┐
│   Nextcloud     │ ◄───────────────── │   Keycloak   │
│   (user_oidc)   │   Web login flow   │   (IdP)      │
└─────────────────┘                    └──────────────┘
```

---

## 1. Keycloak Configuration

### 1.1 Realm and Clients

Ensure your Keycloak realm has at least two OpenID Connect clients:

| Client | Client ID (example) | Purpose |
|--------|---------------------|---------|
| SCS Manager | `https://manager.example.com` | Drupal/SCS Manager login |
| Nextcloud | `https://drive.example.com` | Nextcloud web login and Bearer validation |

Client IDs typically match the service URL (including `https://`). Both clients must:

- Use **Standard flow** (authorization code)
- Have correct **Redirect URIs** (e.g. `https://drive.example.com/*`)
- Share the same **realm**
- Have matching **client secrets** in `.env` and Keycloak Admin

### 1.2 Audience Mapper (Required for Bearer Token Sharing)

When SCS Manager calls Nextcloud APIs with a Bearer token, that token was issued for the SCS Manager client. Nextcloud expects the token's `aud` (audience) claim to include the Nextcloud client ID. Add an **Audience** protocol mapper so SCS Manager tokens also include the Nextcloud client.

**Option A: Add to a client scope (e.g. profile)**

1. Keycloak Admin → **Realm** → **Client scopes** → **profile** (or create a custom scope)
2. **Add mapper** → **By configuration**
3. **Mapper type**: `oidc-audience-mapper`
4. **Included Client Audience**: `https://drive.example.com` (your Nextcloud client ID)
5. Enable **Add to access token** and **Add to ID token**
6. Save

Ensure the profile scope is a **default** scope for the SCS Manager client:

- **Clients** → SCS Manager → **Client scopes** → **Default client scopes** → include `profile`

**Option B: Add directly to SCS Manager client**

1. **Clients** → SCS Manager → **Client scopes** → **Add mapper** → **By configuration**
2. Same settings as above.

### 1.3 Realm Template (SCS deployment)

If using the SCS realm template (`scs-realm.json.tpl`), the **audience-nextcloud** mapper is included on the **profile** client scope (see `protocolMappers` under the `profile` scope). Re-run `01_scripts/keycloak/pre-install.sh` and re-import the realm on new deployments, or add the mapper manually in Keycloak Admin.

Example mapper definition:

```json
{
  "name": "audience-nextcloud",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-audience-mapper",
  "config": {
    "included.client.audience": "https://${NEXTCLOUD_NEXTCLOUD_DOMAIN}",
    "access.token.claim": "true",
    "id.token.claim": "true"
  }
}
```

**Existing deployments:** Keycloak Admin → **Client scopes** → **profile** → **Mappers** — confirm a mapper named `audience-nextcloud` (or `Nextcloud audience`) adds `https://<your-drive-domain>` to token `aud`.

---

## 2. Nextcloud Configuration

### 2.1 Required Apps

| App | Purpose |
|-----|---------|
| **user_oidc** | Drive web login (**Anmelden mit SCS SSO Login**) + Bearer token validation for API requests |
| **sociallogin** | Installed by post-install hook only to supply Keycloak client settings; **disabled** after `configure-user-oidc-bearer.sh` to avoid a second login button |

Install and configure (post-install hooks: `install-sociallogin.sh`, `install-user-oidc.sh`, then `configure-user-oidc-bearer.sh`):

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ app:install sociallogin
docker exec nextcloud--nextcloud php /var/www/html/occ app:enable sociallogin
docker exec nextcloud--nextcloud php /var/www/html/occ app:install user_oidc
docker exec nextcloud--nextcloud php /var/www/html/occ app:enable user_oidc
docker exec nextcloud--nextcloud bash /docker-entrypoint-hooks.d/post-installation/configure-user-oidc-bearer.sh
```

The bearer hook reads Keycloak client settings from sociallogin, registers a single `user_oidc` provider named **SCS SSO Login**, then disables sociallogin.

### 2.2 Drive Web Login (user_oidc)

One provider handles both browser login and Bearer validation:

- **Identifier**: `SCS SSO Login` (button label: *Anmelden mit SCS SSO Login*)
- **Client ID**: Same as Nextcloud client in Keycloak (e.g. `https://drive.example.com`)
- **Client Secret**: Must match Keycloak
- **Discovery**: `https://auth.example.com/realms/your-realm/.well-known/openid-configuration`

### 2.3 user_oidc Provider (Web + Bearer)

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ user_oidc:provider "SCS SSO Login" \
  --clientid "https://drive.example.com" \
  --clientsecret "YOUR_NEXTCLOUD_CLIENT_SECRET" \
  --discoveryuri "https://auth.example.com/realms/your-realm/.well-known/openid-configuration" \
  --check-bearer=1 \
  --bearer-provisioning=1 \
  --mapping-display-name=preferred_username \
  --unique-uid=0 \
  --no-warnings -n
docker exec nextcloud--nextcloud php /var/www/html/occ app:disable sociallogin -n
```

Important flags:

- `--check-bearer=1`: Validate Bearer tokens on API requests
- `--bearer-provisioning=1`: Auto-provision users when Bearer token is valid

**Do not** add a second provider with identifier `Keycloak` — that creates a duplicate login button.

### 2.4 config.php Settings

Add to Nextcloud `config/config.php`:

```php
$config['user_oidc'] = [
  // Enable Bearer token validation for API requests
  'oidc_provider_bearer_validation' => true,

  // Disable azp check: tokens from SCS Manager have azp = SCS Manager client,
  // not Nextcloud. Audience check is sufficient for security.
  'bearer_validation_azp_check' => false,
];
```

| Setting | Value | Purpose |
|---------|-------|---------|
| `oidc_provider_bearer_validation` | `true` | Enable Bearer token validation |
| `bearer_validation_azp_check` | `false` | Allow tokens where `azp` is SCS Manager (cross-client) |

**Why disable `bearer_validation_azp_check`?**

The `azp` (authorized party) claim identifies who requested the token — always the SCS Manager client. Nextcloud would reject these tokens if it required `azp` to match its own client ID. The `aud` (audience) check, enforced via the Keycloak audience mapper, already ensures the token is intended for Nextcloud.

---

## 3. Verification

### 3.1 Web Login

1. Log out of Nextcloud.
2. Open Nextcloud login page.
3. Click the Keycloak/SSO login button.
4. You should be redirected to Keycloak and back to Nextcloud without re-entering credentials (if already logged in elsewhere).

### 3.2 Bearer Token Verification

While logged in via Keycloak, go to **Connected Accounts** (`/user/{id}/connected-accounts`). The Nextcloud section shows the connection status:

- **Connected via SSO** — Bearer token (audience) is accepted by Nextcloud.
- **Connected via app password** — Login Flow v2 credentials are stored (fallback when Bearer is not configured).

### 3.3 Checklist

- [ ] Keycloak: audience mapper on profile scope **and** SCS Manager client (tokens must include Drive client ID in `aud`)
- [ ] SCS Manager Drupal OIDC client requests `profile` scope
- [ ] Nextcloud: `user_oidc` enabled, provider **SCS SSO Login** with `--check-bearer=1`
- [ ] Nextcloud: `sociallogin` disabled (no duplicate login button)
- [ ] config.php: `oidc_provider_bearer_validation` = true, `bearer_validation_azp_check` = false
- [ ] User logged out and back in to SCS Manager after audience mapper changes (fresh access token)

---

## 4. Troubleshooting

### 401 "Current user is not logged in" from Nextcloud

**Cause**: Nextcloud rejects the Bearer token.

**Checks**:

1. **Audience**: Token `aud` must include the Nextcloud client ID. Add the audience mapper and ensure SCS Manager requests the `profile` scope.
2. **azp check**: Disable `bearer_validation_azp_check` in config.php (see 2.4).
3. **Stale token**: Log out and log back in to SCS Manager to get a new access token with the correct `aud` (ID tokens are not used for Bearer checks).
4. **user_oidc provider**: Verify `check_bearer=1` via `occ user_oidc:providers`.

### Bearer OK but automatic connect still fails (getapppassword 404)

**Cause**: On SSO-only Drive accounts, `GET /ocs/v2.php/core/getapppassword` does not work with a Bearer token (nginx 404 / no session password). SCS Manager falls back to `occ user:add-app-password` inside the `nextcloud--nextcloud` container.

**Checks**:

1. Portainer/docker-exec from SCS Manager must reach `nextcloud--nextcloud`.
2. Drupal log: `Nextcloud SSO occ app password failed` — inspect occ output.
3. Legacy sociallogin users may have Drive id = raw Keycloak `sub` (no `keycloak-` prefix); stored credentials must use that id for Basic auth.

### Two SSO buttons on the Drive login page

**Cause**: Both **sociallogin** and **user_oidc** were active — e.g. provider identifier `Keycloak` alongside sociallogin's *SCS SSO Login*.

**Fix**: Keep a single `user_oidc` provider named `SCS SSO Login`, delete any legacy `Keycloak` provider, disable sociallogin:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ user_oidc:provider:delete Keycloak --force -n
docker exec nextcloud--nextcloud php /var/www/html/occ app:disable sociallogin -n
```

Or re-run `configure-user-oidc-bearer.sh`.

### Token claims for debugging

Decode your access token (base64url-decode the middle part). You should see:

```json
{
  "iss": "https://auth.example.com/realms/your-realm",
  "aud": ["https://manager.example.com", "https://drive.example.com"],
  "azp": "https://manager.example.com",
  "sub": "..."
}
```

`aud` must contain the Nextcloud client ID. `azp` will be the SCS Manager client — that is expected when `bearer_validation_azp_check` is disabled.

### Social Login not showing Keycloak button

- Verify Social Login custom_providers includes the Keycloak provider with correct client ID, secret, and URLs.
- Check Nextcloud logs: `docker exec nextcloud--nextcloud tail -f /var/www/html/data/nextcloud.log`

### user_oidc provider not found

Re-run the `user_oidc:provider` command. Ensure the client secret matches Keycloak exactly (no extra spaces or encoding issues).

### Login Flow v2 returns 403 / `user=` empty (Connect popup)

**Cause**: Login Flow v2’s grant page does not show the Social Login (Keycloak) button when `hide_default_login=1`. New users cannot authenticate inside the SCS Manager popup.

**Recommended fix**: Enable **Use OIDC Bearer token for Nextcloud** in SCS Manager settings and ensure `user_oidc` Bearer validation is configured (see §2.3). The first-login wizard then verifies Drive via the existing Keycloak session — no popup.

**Legacy workaround**: Log into Drive once at `/login` via **Log in with SCS SSO Login**, then retry Connect.

### App password creation fails / "app client account is not created"

**Cause**: The Nextcloud `user_oidc` account does not exist yet and bearer-provisioning is disabled or the Bearer token is rejected (missing `aud` audience).

**Solution**:

- With **Bearer mode** and `--bearer-provisioning=1`: the first successful status check or API call from SCS Manager auto-provisions `keycloak-{sub}` — no separate Drive web login required.
- Otherwise: log into Drive via Social Login once, then retry.

**Verify bearer-provisioning**:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ config:list --private | grep -i bearer
```

---

## 5. Environment Variables (SCS Deployment)

Relevant variables for the SCS deployment:

| Variable | Description |
|----------|-------------|
| `NEXTCLOUD_NEXTCLOUD_DOMAIN` | Nextcloud URL, used as client ID (e.g. `drive.example.com`) |
| `NEXTCLOUD_CLIENT_SECRET` | Nextcloud Keycloak client secret |
| `SCS_MANAGER_DOMAIN` | SCS Manager URL, used as client ID |
| `KC_DOMAIN` | Keycloak base URL (e.g. `https://auth.example.com`) |
| `KC_REALM` | Keycloak realm name |

Post-install hooks (`configure-user-oidc-bearer.sh`, `install-sociallogin.sh`) use these to configure Nextcloud automatically.

---

## Related documentation

- [SCS Manager user create and delete routines](../service-infrastructure/scs-manager-user-lifecycle.md) — Keycloak user provisioning, Nextcloud credential attributes in Keycloak, validation, and cleanup when a Drupal user is deleted.
