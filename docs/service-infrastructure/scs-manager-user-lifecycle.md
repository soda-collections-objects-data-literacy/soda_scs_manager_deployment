# SCS Manager — user create and delete routines

Technical reference for how the SCS Manager (`soda_scs_manager` Drupal module) provisions and tears down users across Keycloak, Nextcloud, MariaDB, OpenGDB, and related SCS entities.

Implementation lives in the `scs-manager-stack` submodule under `volumes/drupal/web/modules/custom/soda_scs_manager/`.

## Identity model

| Layer | Identifier | Where stored |
|-------|------------|--------------|
| Keycloak | UUID (`sub` claim) | Keycloak user record |
| Drupal ↔ Keycloak | Same UUID | `authmap` table (`openid_connect.<client_id>`) |
| Nextcloud (OIDC) | `keycloak-{sub}` | Nextcloud user backend (`user_oidc` / Social Login) |
| Keycloak user attributes | `nextcloud_login_name`, `nextcloud_app_password`, `mariadb_password`, … | Keycloak user `attributes` |

`SodaScsProjectHelpers::getUserSsoUuid()` reads the Keycloak UUID from Drupal’s `authmap` after the user has logged in via OpenID Connect.

Nextcloud usernames for OIDC users follow the pattern configured in SCS Manager settings (`oidcUsernamePrefix`, default `keycloak-`) plus the raw Keycloak `sub`, e.g. `keycloak-4e25a3ff-b955-4731-9c56-9e67a858828d`.

JupyterHub reads `nextcloud_login_name` and `nextcloud_app_password` from Keycloak **userinfo** (protocol mappers on the JupyterHub client). It does not derive the Nextcloud account from `sub` directly.

---

## User creation routines

### 1. Self-registration (pending → Keycloak)

**UI:** `KeycloakUserRegistrationForm` → route `soda_scs_manager.user_registration`

1. User submits registration (username, email, password, locale, timezone).
2. Row is inserted into custom table `keycloak_user_registration` with `status = pending`.
3. No Keycloak or Drupal account is created yet.

**Admin approval:** `KeycloakUserApprovalForm::approveRegistration()`

1. Obtain Keycloak admin token (`grant_type=password`, `client_id=admin-cli`, credentials from SCS Manager settings).
2. `POST {KC_URL}/admin/realms/{realm}/users` via `SodaScsKeycloakServiceUserActions::buildCreateRequest()`.
3. Body includes `username`, `email`, `firstName`, `lastName`, `credentials`, optional `attributes.locale`.
4. Registration row updated to `status = approved`; approval email sent.

Keycloak assigns a new UUID (`sub`) for the user. That UUID is **not** written to Drupal until the user logs in via OIDC.

### 2. First login — Drupal user (`hook_user_insert`)

When the approved user signs in through Keycloak (OpenID Connect), Drupal’s `openid_connect` module creates or links the Drupal account and writes the Keycloak `sub` into `authmap`.

`hook_user_insert()` then:

- Activates the user and assigns role `scs_user`
- Creates default project and applications
- Propagates Keycloak profile fields (locale, timezone) via `_soda_scs_manager_propagate_keycloak_user_data_to_fields()`

No Keycloak API call happens in this hook — the Keycloak user already exists.

### 3. Nextcloud account creation

Nextcloud accounts are **not** created by the Keycloak approval step. They appear when the user first authenticates against Nextcloud:

| Path | Mechanism | Resulting NC username |
|------|-----------|------------------------|
| Web login (Drive UI) | Social Login → Keycloak | `keycloak-{sub}` (auto-provision) |
| SCS Manager first-login wizard (recommended) | OIDC Bearer + `user_oidc` bearer-provisioning | `keycloak-{sub}` |
| SCS Manager Connect popup (legacy) | Login Flow v2 → poll | Account user logs into in the popup |
| Bearer / API | `user_oidc` with `--bearer-provisioning=1` | `keycloak-{sub}` |

The skeleton directory (`SCS-Share`, `Welcome.md`, …) is applied on **first** Nextcloud user creation via Nextcloud’s `skeletondirectory` config (see post-install hook).

### 4. Nextcloud credentials in Keycloak

Stored attributes (default names):

- `nextcloud_login_name`
- `nextcloud_app_password`

**Bearer SSO check (recommended)** — `SodaScsNextcloudConnectController::status()` when `useBearerToken` is enabled (default):

1. Calls `ensureCredentials()` (validates stored Keycloak attributes or creates an app password via Bearer token).
2. Returns `connected: true` only when credentials are actually ready for WissKI — not merely when the OIDC token validates.
3. The co-working intro wizard skips the Connect slide only when this status check succeeds.
4. When Bearer fails, the response includes `bearer_error` and the UI shows **Connect Drive manually** (Login Flow v2 popup). See [Nextcloud Drive connection troubleshooting](../troubleshooting/nextcloud-drive-connect.md).

Enable in SCS Manager settings: **Nextcloud → Use OIDC Bearer token for Nextcloud** (`nextcloud.generalSettings.useBearerToken`).

**Connect flow (Login Flow v2, manual fallback)** — `SodaScsNextcloudConnectController` when Bearer mode is disabled or automatic SSO failed:

1. `POST /index.php/login/v2` → user completes login in popup
2. Poll returns `loginName` + `appPassword`
3. Values are written to Keycloak via `setKeycloakUserAttributes()`
4. **Validation:** `loginName` must match `keycloak-{sub}` for the current Drupal user; otherwise the connect is rejected (HTTP 400).

**Bearer auto-provision** — `SodaScsNextcloudHelpers::ensureCredentials()` (when `useBearerToken` is enabled):

1. If validated stored credentials exist → return them
2. Else create app password via OIDC Bearer token → `GET /ocs/v2.php/core/getapppassword`
3. Persist username + app password to Keycloak attributes

**Validation on read** — `getValidatedStoredNextcloudCredentials()`:

- Stored username must equal `keycloak-{sub}`
- App password must still work against Nextcloud
- On mismatch or invalid password → attributes are **cleared** (user must reconnect)

**On login** — `hook_user_login()` calls `invalidateMismatchedStoredCredentials()` to drop stale attributes after Keycloak user recreation or SSO relinking.

### 5. MariaDB / phpMyAdmin credentials

When a user creates an SQL component or is granted project DB access:

- MariaDB user is created or updated
- `mariadb_password` is synced to Keycloak attributes (`SodaScsSqlComponentActions`, `SodaScsProjectDbAccessHelpers`)

phpMyAdmin SSO reads `preferred_username` and `mariadb_password` from the JWT. See [DBMS SSO troubleshooting](../troubleshooting/dbms-sso-redirect-loop.md).

### 6. Other provision-on-use resources

| Resource | Created when | Deleted when |
|----------|--------------|--------------|
| OpenGDB / triplestore user | Triplestore component | Component delete or user delete |
| WissKI stack | WissKI component via Portainer | Component/stack delete |
| Keycloak groups/clients | WissKI component setup | WissKI component delete |

---

## User deletion routines

### Trigger

Keycloak (and downstream cleanup) runs **only** when a **Drupal user is deleted** in SCS Manager — `hook_user_delete()` in `soda_scs_manager.module`.

Deleting a user directly in the Keycloak Admin Console does **not** invoke this hook. Nextcloud, MariaDB, and Drupal data are then **not** cleaned up automatically.

### Deletion sequence

```mermaid
sequenceDiagram
    participant Admin
    participant Drupal
    participant Hook as hook_user_delete
    participant NC as Nextcloud OCS API
    participant KC as Keycloak Admin API
    participant DB as MariaDB / OpenGDB

    Admin->>Drupal: Delete Drupal user
    Drupal->>Hook: soda_scs_manager_user_delete()
    Hook->>Hook: getUserSsoUuid() from authmap
    alt SSO link present
        Hook->>NC: deleteNextcloudAccountForKeycloakUser()
        Note over NC: Revoke app password; DELETE user if admin creds set
        Hook->>KC: POST token (admin-cli)
        Hook->>KC: DELETE /admin/realms/{realm}/users/{userId}
    else no SSO link
        Hook->>Hook: Skip Keycloak delete
    end
    Hook->>DB: cleanServiceUsers (MariaDB)
    Hook->>DB: OpenGDB user delete
    Hook->>Drupal: Delete snapshots, components, stacks, projects, service keys
```

### Step-by-step

1. **Jupyter notebook stop** — `SodaScsJupyterHelpers::stopNotebookContainerForUser($user)` (always, before other cleanup):
   - Stops the DockerSpawner notebook container (`jupyter-{drupalAccountName}` by default) via Portainer Docker API
   - Does **not** remove the container forcibly with volume flags and does **not** delete `jupyterhub-user-{username}` data volumes
   - No-op when the container does not exist or is already stopped

2. **Resolve Keycloak ID** — `getUserSsoUuid($user)` from `authmap`. If missing, Keycloak delete is skipped (logged).

3. **Nextcloud cleanup** — `SodaScsNextcloudHelpers::deleteNextcloudAccountForKeycloakUser($keycloakUserId)`:
   - Revoke stored app password (`DELETE /ocs/v2.php/core/apppassword`) if attributes exist
   - Delete Nextcloud user(s) via `DELETE /ocs/v1.php/cloud/users/{userid}` when **Nextcloud admin credentials** are configured in SCS Manager settings (`/admin/config/soda-scs-manager/settings` → Nextcloud tab)
   - Attempts both the expected account (`keycloak-{sub}`) and any previously stored username (orphaned account from an old `sub`)
   - Clears `nextcloud_login_name` / `nextcloud_app_password` in Keycloak

4. **Keycloak user delete**:
   - Admin token: `POST {KC_URL}/realms/master/protocol/openid-connect/token` with `client_id=admin-cli` and admin username/password from module settings
   - `DELETE {KC_URL}/admin/realms/{realm}/users/{userId}` with `Authorization: Bearer <token>`
   - Entire Keycloak user record (including all attributes) is removed

5. **MariaDB** — `SodaScsSqlServiceActions::cleanServiceUsers()` drops SQL service users owned by the display name.

6. **OpenGDB / triplestore** — delete request via `SodaScsOpenGdbServiceActions::buildDeleteRequest()`.

7. **SCS entities** — owned snapshots, components, stacks, projects, and service keys are deleted.

### API route configuration

Keycloak Admin API paths are configured in SCS Manager settings (Keycloak tab → Users → CRUD). Typical values:

| Setting | Example |
|---------|---------|
| Base URL | `/admin/realms/{realm}/users` |
| Create URL | (empty or `/`) → `POST` creates user |
| Delete URL | `/{userId}` → `DELETE` removes user |

Token URL and realm come from the same Keycloak settings block (`initKeycloakGeneralSettings()`, `initKeycloakUsersSettings()`).

---

## Configuration checklist

| Setting | Purpose |
|---------|---------|
| Keycloak → Admin username / password | Admin API token for create/delete user |
| Keycloak → Users → delete URL | Path segment for `DELETE` (usually `/{userId}`) |
| Nextcloud → Base URL | OCS API base |
| Nextcloud → OIDC username prefix | Must match Nextcloud `user_oidc` provider (default `keycloak-`) |
| Nextcloud → Admin username / password | Optional; required for automatic NC user delete on Drupal user delete |
| Nextcloud → Keycloak attribute names | Defaults: `nextcloud_login_name`, `nextcloud_app_password` |
| JupyterHub → Notebook container name prefix | Default `jupyter-`; must match DockerSpawner naming (`jupyter-{drupalAccountName}`) |

---

## Known gaps and pitfalls

### Orphaned accounts after manual Keycloak changes

If a Keycloak user is deleted or recreated **outside** SCS Manager (Admin UI, import, realm reset):

- Drupal `authmap` may still point to the old or a new `sub`
- Nextcloud may retain old `keycloak-{old-sub}` accounts
- Keycloak attributes (`nextcloud_login_name`, …) may reference the **wrong** Nextcloud account

**Symptom:** User sees correct files in Nextcloud web UI but JupyterHub (or other services reading Keycloak userinfo) sync to a different Nextcloud account.

**Mitigation (module behaviour):**

- Login invalidates mismatched Nextcloud attributes
- Connect flow refuses wrong `loginName`
- `getValidatedStoredNextcloudCredentials()` clears stale attributes

**Operational fix:** User re-runs Nextcloud Connect in SCS Manager; optionally delete orphaned Nextcloud users manually.

### Nextcloud delete requires admin API credentials

Without Nextcloud admin username/password in SCS Manager settings, user deletion only revokes the app password and clears Keycloak attributes. The Nextcloud user directory remains until deleted manually (`occ user:delete` or Admin UI).

### Registration approval ≠ Drupal account

Approving registration creates the Keycloak user only. The Drupal account appears on first OIDC login. Nextcloud and Keycloak credential attributes are provisioned later (Connect flow or Bearer auto-provision).

---

## Manual operations

### Delete Keycloak user (without Drupal cleanup)

```bash
# Token
curl -s -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN}" -d "password=${KC_ADMIN_PASSWORD}"

# Delete
curl -X DELETE "${KC_URL}/admin/realms/${KC_REALM}/users/${KEYCLOAK_UUID}" \
  -H "Authorization: Bearer ${TOKEN}"
```

Prefer deleting the **Drupal user** in SCS Manager so Nextcloud, SQL, and SCS entities are cleaned up.

---

## Entity access control

| Entity | View | Edit / delete | Create snapshot |
|--------|------|----------------|-----------------|
| Project | Owner or project member | Owner only | — |
| Component | Any user with `view soda scs component` | Owner only (`owner` field) | Owner of the component only |
| Stack | Any user with `view soda scs stack` | Owner only (`owner` field) | Owner of the stack only |
| Snapshot | Owner only | Owner only | Via component/stack routes (owner of source entity) |

Project members can use shared components and stacks (e.g. via the dashboard) but cannot change, remove, or snapshot entities they do not own. Edit, delete, and snapshot tabs, list operations, and form routes enforce this via the entity access handlers.

Users with `soda scs manager admin` or the entity-specific `administer soda scs * entities` permissions bypass owner checks (full edit, delete, and snapshot access).

### Delete Nextcloud user

```bash
docker exec nextcloud--nextcloud php /var/www/html/occ user:delete "keycloak-${KEYCLOAK_UUID}"
```

Or configure Nextcloud admin credentials in SCS Manager and rely on `hook_user_delete()`.

---

## Related documentation

- [Keycloak and Nextcloud integration](../post-configuration/keycloak-nextcloud.md) — OIDC, Bearer tokens, audience mapper
- [Post-configuration checklist](../post-configuration/checklist.md) — Keycloak clients, groups, Nextcloud Social Login
- [WissKI stack integration](wisski-stack/index.md) — Portainer-based stack create/delete
- [DBMS SSO redirect loop](../troubleshooting/dbms-sso-redirect-loop.md) — `mariadb_password` and phpMyAdmin
