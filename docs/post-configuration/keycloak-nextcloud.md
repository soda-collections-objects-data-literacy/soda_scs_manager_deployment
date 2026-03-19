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

If using the SCS realm template (`scs-realm.json.tpl`), add the audience mapper to the profile scope or SCS Manager client in the JSON. Example for a client-level mapper:

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

---

## 2. Nextcloud Configuration

### 2.1 Required Apps

| App | Purpose |
|-----|---------|
| **sociallogin** | Web login via Keycloak (OAuth redirect flow) |
| **user_oidc** | OIDC user backend + Bearer token validation for API requests |

Install and enable both:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ app:install sociallogin
docker exec nextcloud--nextcloud php /var/www/html/occ app:enable sociallogin
docker exec nextcloud--nextcloud php /var/www/html/occ app:install user_oidc
docker exec nextcloud--nextcloud php /var/www/html/occ app:enable user_oidc
```

### 2.2 Social Login (Web Login)

Configure the Keycloak provider via environment variables or `occ`:

- **Client ID**: Same as Nextcloud client in Keycloak (e.g. `https://drive.example.com`)
- **Client Secret**: Must match Keycloak
- **Realm**: Your Keycloak realm name
- **Discovery**: `https://auth.example.com/realms/your-realm/.well-known/openid-configuration`

The Social Login app handles the web login flow (redirect to Keycloak, callback, session creation).

### 2.3 user_oidc Provider (Bearer Token Validation)

Add a Keycloak provider to `user_oidc` with Bearer validation enabled:

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ user_oidc:provider Keycloak \
  --clientid "https://drive.example.com" \
  --clientsecret "YOUR_NEXTCLOUD_CLIENT_SECRET" \
  --discoveryuri "https://auth.example.com/realms/your-realm/.well-known/openid-configuration" \
  --check-bearer=1 \
  --bearer-provisioning=1 \
  --mapping-display-name=preferred_username \
  --unique-uid=0 \
  --no-warnings -n
```

Important flags:

- `--check-bearer=1`: Validate Bearer tokens on API requests
- `--bearer-provisioning=1`: Auto-provision users when Bearer token is valid

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

- [ ] Keycloak realm has SCS Manager and Nextcloud clients
- [ ] Audience mapper adds Nextcloud client ID to SCS Manager tokens (profile scope or client-level)
- [ ] Profile scope is a default scope for SCS Manager client
- [ ] Nextcloud: sociallogin and user_oidc apps installed and enabled
- [ ] user_oidc provider configured with `--check-bearer=1`
- [ ] config.php: `oidc_provider_bearer_validation` = true, `bearer_validation_azp_check` = false
- [ ] User logged out and back in after adding audience mapper (to get fresh token)

---

## 4. Troubleshooting

### 401 "Current user is not logged in" from Nextcloud

**Cause**: Nextcloud rejects the Bearer token.

**Checks**:

1. **Audience**: Token `aud` must include the Nextcloud client ID. Add the audience mapper and ensure the profile scope is in SCS Manager's default scopes.
2. **azp check**: Disable `bearer_validation_azp_check` in config.php (see 2.4).
3. **Stale token**: Log out and log back in to SCS Manager to get a new token with the correct `aud`.
4. **user_oidc provider**: Verify `check_bearer=1` via `occ config:list --private` and look for `provider-1-checkBearer`.

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

### App password creation fails / "app client account is not created"

**Cause**: The Nextcloud user_oidc account does not exist yet. Bearer-based app password creation and Login Flow v2 require the user to exist in Nextcloud.

**Solution**: Log into Nextcloud via the web at least once using Keycloak/SSO (Social Login). This creates the user_oidc account. After that:

- **Bearer flow**: SCS Manager can create app passwords via `createAppPassword` (e.g. when creating a WissKI component).
- **Login Flow v2**: The "Connect via app password" flow on the Connected Accounts page will work.

**Verify**:

1. Open Nextcloud in a browser, log out if needed.
2. Click the Keycloak/SSO login button and complete the flow.
3. You should land on the Nextcloud dashboard. The account is now created.
4. Return to SCS Manager and create a WissKI or use "Connect via app password".

**Check bearer-provisioning**: Ensure the user_oidc provider has `--bearer-provisioning=1` (auto-provision users when Bearer token is valid). The post-install hook `configure-user-oidc-bearer.sh` sets this. Verify with:

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
