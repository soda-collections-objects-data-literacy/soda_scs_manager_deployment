# Nextcloud Drive connection (SCS Manager)

When SCS Manager cannot reach Drive automatically, use the manual connect flow and check for duplicate Nextcloud accounts.

## Symptoms

- Watchdog: `Nextcloud SSO status check failed` or `401 Unauthorized` on `/ocs/v1.php/cloud/user`
- UI: *Connecting Drive via SSO failed*
- Nextcloud log: `App token login name does not match` (stored username vs the Drive account used for WebDAV)

## Automatic SSO (Bearer) vs manual connect

With **Use OIDC Bearer token for Nextcloud** enabled (`nextcloud.generalSettings.useBearerToken`), SCS Manager first tries to provision credentials via the Manager Keycloak access token. That only works when Nextcloud accepts that token (same realm, compatible client/audience).

When Bearer fails, the UI shows **Connect Drive manually** (Login Flow v2):

1. Open **Connected Accounts** (`/user/{uid}/connected-accounts`) or complete the co-working intro Drive step.
2. Click **Connect Drive manually**.
3. Sign in in the popup with the **same Keycloak account** as SCS Manager.
4. SCS Manager stores `nextcloud_login_name` and `nextcloud_app_password` in Keycloak.

The connect button appears when the status check returns `bearer_error` or the check fails entirely.

**Bearer and manual connect store the same identifier:** the Nextcloud `loginName` / `cloud/user` id returned by Drive (on this deployment, the raw Keycloak `sub` from `user_oidc`). Neither flow creates a separate account type.

## OIDC username prefix (`oidcUsernamePrefix`)

SCS Manager setting **Nextcloud → OIDC username prefix** (`nextcloud.generalSettings.oidcUsernamePrefix`) must match how `user_oidc` provisions Drive users:

| Deployment | Prefix | Drive account id |
|------------|--------|------------------|
| **Current (`user_oidc`, `--unique-uid=0`)** | *(empty)* | Raw Keycloak `sub` |
| Legacy (**sociallogin** / old docs) | `keycloak-` | `keycloak-{sub}` |

On this host the prefix is **empty**. In SCS Manager config use the sentinel `{empty}` (the module treats a bare empty string as “not set”):

```bash
docker compose exec -T scs-manager--drupal drush config:set soda_scs_manager.settings nextcloud.generalSettings.oidcUsernamePrefix '{empty}' -y
```

If the prefix in SCS Manager does not match the real Drive account id, status checks and WissKI mounts may target the wrong user while the Drive web UI shows another.

## Duplicate Nextcloud accounts (legacy mismatch)

`user_oidc` provisions **one account per Keycloak `sub`** (raw UUID). Legacy installs may **also** have a **`keycloak-{sub}`** account from the old **sociallogin** stack for the same person.

**Symptom:** The Drive web UI and Keycloak `nextcloud_login_name` point at different accounts; SCS-Share contents differ.

**Cleanup** (keep the raw `sub` / `user_oidc` account, remove the legacy prefixed one when it is unused):

```bash
# List both forms for a Keycloak sub fragment
docker exec --user www-data nextcloud--nextcloud--app php /var/www/html/occ user:list | grep {sub-fragment}

# Optional: copy SCS-Share from legacy account first
docker exec nextcloud--nextcloud--app bash -c '
  SRC=/var/www/html/data/keycloak-{sub}/files/SCS-Share
  DST=/var/www/html/data/{sub}/files/SCS-Share
  mkdir -p "$DST" && cp -n "$SRC"/* "$DST/" 2>/dev/null || true
'

# Delete legacy prefixed account
docker exec --user www-data nextcloud--nextcloud--app php /var/www/html/occ user:delete keycloak-{sub}
```

Clear stale Keycloak attributes if needed (SCS Manager clears them automatically when validation fails):

- `nextcloud_login_name`
- `nextcloud_app_password`

Then reconnect Drive in SCS Manager (Bearer or manual). JupyterHub does not use these credentials: project notebooks mount the Team Folder through the service account `scs-jupyter`.

See also the full [SCS Drive connection runbook](scs-drive-jupyter-connection.md) (user vs admin steps, what to restart).

## WebDAV

### WebDAV lists fewer files than the Drive UI

Files copied on the Nextcloud host (e.g. migration between accounts) may not appear over WebDAV until indexed:

```bash
docker exec --user www-data nextcloud--nextcloud--app php occ files:scan {nextcloud-user-id} --path=/{nextcloud-user-id}/files/SCS-Share
```

## Verify

```bash
# One Drive account per Keycloak sub (plus optional legacy keycloak- duplicate)
docker exec --user www-data nextcloud--nextcloud--app php /var/www/html/occ user:list | grep {sub-fragment}

# Keycloak attribute (via SCS Manager / Admin API) should match the user_oidc account id
# nextcloud_login_name = {sub}

# SCS Manager status (logged in as affected user in browser)
# GET /soda-scs-manager/nextcloud/connect/status → connected: true, username: {sub}
```

## Related

- [SCS Manager user lifecycle — Nextcloud credentials](../service-infrastructure/scs-manager-user-lifecycle.md#4-nextcloud-credentials-in-keycloak)
- [Keycloak ↔ Nextcloud](../post-configuration/keycloak-nextcloud.md)
