# Nextcloud Drive connection (SCS Manager)

When SCS Manager cannot reach Drive automatically, use the manual connect flow and check for duplicate Nextcloud accounts.

## Symptoms

- Watchdog: `Nextcloud SSO status check failed` or `401 Unauthorized` on `/ocs/v1.php/cloud/user`
- UI: *Connecting Drive via SSO failed*
- Nextcloud log: `App token login name does not match` (stored username without `keycloak-` prefix vs account with prefix)

## Automatic SSO (Bearer) vs manual connect

With **Use OIDC Bearer token for Nextcloud** enabled (`nextcloud.generalSettings.useBearerToken`), SCS Manager first tries to provision credentials via the Manager Keycloak access token. That only works when Nextcloud accepts that token (same realm, compatible client/audience).

When Bearer fails, the UI shows **Connect Drive manually** (Login Flow v2):

1. Open **Connected Accounts** (`/user/{uid}/connected-accounts`) or complete the co-working intro Drive step.
2. Click **Connect Drive manually**.
3. Sign in in the popup with the **same Keycloak account** as SCS Manager.
4. SCS Manager stores `nextcloud_login_name` and `nextcloud_app_password` in Keycloak.

The connect button appears when the status check returns `bearer_error` or the check fails entirely.

## Duplicate Nextcloud accounts (Keycloak mismatch)

OIDC users should have a single account: `keycloak-{keycloak-sub}` (e.g. `keycloak-e04653d5-a341-48e6-8033-5ec2e5352408`).

Legacy installs may also have a **raw UUID** account (`e04653d5-...`) from an old Social Login setup. That causes app-password validation to fail because credentials belong to the prefixed account.

**Cleanup** (keep `keycloak-{sub}`, remove raw UUID):

```bash
docker exec --user www-data nextcloud--nextcloud php /var/www/html/occ user:delete {raw-uuid-without-prefix}
```

Clear stale Keycloak attributes if needed (SCS Manager clears them automatically when validation fails):

- `nextcloud_login_name`
- `nextcloud_app_password`

Then run **Connect Drive manually** again.

## Verify

```bash
# One account per Keycloak sub
docker exec --user www-data nextcloud--nextcloud php /var/www/html/occ user:list | grep {sub-fragment}

# SCS Manager status (logged in as affected user in browser)
# GET /soda-scs-manager/nextcloud/connect/status → connected: true, method: stored
```

## Related

- [SCS Manager user lifecycle — Nextcloud credentials](../service-infrastructure/scs-manager-user-lifecycle.md#4-nextcloud-credentials-in-keycloak)
- [Keycloak ↔ Nextcloud](../post-configuration/keycloak-nextcloud.md)
