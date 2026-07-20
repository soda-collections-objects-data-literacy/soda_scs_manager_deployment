# Nextcloud Drive connection (SCS Manager)

When SCS Manager cannot reach Drive automatically, use the manual connect flow and check for duplicate Nextcloud accounts.

## Symptoms

- Watchdog: `Nextcloud SSO status check failed` or `401 Unauthorized` on `/ocs/v1.php/cloud/user`
- UI: *Connecting Drive via SSO failed*
- Nextcloud log: `App token login name does not match` (stored username vs the Drive account used for WebDAV)
- JupyterHub sync succeeds with no errors but files do not appear in the Drive UI (or vice versa) — often a **duplicate account** or a **stale Jupyter spawn** (see below)

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

If the prefix in SCS Manager does not match the real Drive account id, status checks and JupyterHub may target the wrong user while the Drive web UI shows another.

## Duplicate Nextcloud accounts (legacy mismatch)

`user_oidc` provisions **one account per Keycloak `sub`** (raw UUID). Legacy installs may **also** have a **`keycloak-{sub}`** account from the old **sociallogin** stack for the same person.

**Symptom:** Drive web UI and JupyterHub (or Keycloak `nextcloud_login_name`) point at different accounts; SCS-Share contents differ.

**Cleanup** (keep the raw `sub` / `user_oidc` account, remove the legacy prefixed one when it is unused):

```bash
# List both forms for a Keycloak sub fragment
docker exec --user www-data nextcloud--nextcloud php /var/www/html/occ user:list | grep {sub-fragment}

# Optional: copy SCS-Share from legacy account first
docker exec nextcloud--nextcloud bash -c '
  SRC=/var/www/html/data/keycloak-{sub}/files/SCS-Share
  DST=/var/www/html/data/{sub}/files/SCS-Share
  mkdir -p "$DST" && cp -n "$SRC"/* "$DST/" 2>/dev/null || true
'

# Delete legacy prefixed account
docker exec --user www-data nextcloud--nextcloud php /var/www/html/occ user:delete keycloak-{sub}
```

Clear stale Keycloak attributes if needed (SCS Manager clears them automatically when validation fails):

- `nextcloud_login_name`
- `nextcloud_app_password`

Then reconnect Drive in SCS Manager (Bearer or manual). **Respawn the Jupyter server** from the Hub (Stop → Start) so `NC_LOGIN_NAME` is refreshed from Keycloak.

See also the full [SCS Drive ↔ Jupyter connection runbook](scs-drive-jupyter-connection.md) (user vs admin steps, what to restart).

## JupyterHub SCS-Share sync errors

### `permission denied` on `.../scs-nextcloud-sync/bisync/*.lck`

**Cause:** `~/.cache/scs-nextcloud-sync/` (or files under `SCS-Share/`) were created as **root**, e.g. after debugging with `docker exec jupyter-{user} ...` without `-u jovyan`. The JupyterLab cloud sync runs as `jovyan` and cannot create rclone lock files in a root-owned workdir.

**Fix** (replace `{user}` with the Hub username):

```bash
docker exec jupyter-{user} chown -R jovyan:users /home/jovyan/.cache/scs-nextcloud-sync /home/jovyan/SCS-Share
```

When testing sync from the host, always use the notebook user:

```bash
docker exec -u jovyan jupyter-{user} python3 -c "from scs_nextcloud_sync.handlers import _run_nextcloud_sync; print(_run_nextcloud_sync()['ok'])"
```

### `cannot find prior Path1 or Path2 listings` / bisync aborted after account change

**Cause:** Bisync state under `~/.cache/scs-nextcloud-sync/bisync/` still refers to the **previous** Nextcloud account (e.g. after fixing `NC_LOGIN_NAME` or deleting a legacy `keycloak-{sub}` user).

**Fix:**

```bash
docker exec -u jovyan jupyter-{user} rm -rf /home/jovyan/.cache/scs-nextcloud-sync/bisync /home/jovyan/.cache/scs-nextcloud-sync/bisync.initialized
```

Then trigger sync again from JupyterLab (first run re-bootstraps with `--resync`).

### WebDAV lists fewer files than the Drive UI

Files copied on the Nextcloud host (e.g. migration between accounts) may not appear over WebDAV until indexed:

```bash
docker exec --user www-data nextcloud--nextcloud php occ files:scan {nextcloud-user-id} --path=/{nextcloud-user-id}/files/SCS-Share
```

## Verify

```bash
# One Drive account per Keycloak sub (plus optional legacy keycloak- duplicate)
docker exec --user www-data nextcloud--nextcloud php /var/www/html/occ user:list | grep {sub-fragment}

# Keycloak attribute (via SCS Manager / Admin API) should match the user_oidc account id
# nextcloud_login_name = {sub}

# Jupyter single-user server after respawn
docker inspect jupyter-{username} --format '{{range .Config.Env}}{{println .}}{{end}}' | grep ^NC_LOGIN

# SCS Manager status (logged in as affected user in browser)
# GET /soda-scs-manager/nextcloud/connect/status → connected: true, username: {sub}
```

## Related

- [SCS Manager user lifecycle — Nextcloud credentials](../service-infrastructure/scs-manager-user-lifecycle.md#4-nextcloud-credentials-in-keycloak)
- [Keycloak ↔ Nextcloud](../post-configuration/keycloak-nextcloud.md)
