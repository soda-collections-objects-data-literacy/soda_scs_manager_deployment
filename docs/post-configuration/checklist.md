# Post-configuration checklist

Use this checklist after the whole environment has started (`docker compose up -d`) to ensure each service is correctly wired and configured.

---

## Keycloak

- [ ] **Client secrets** — Confirm that the secrets in `.env` match what is in the Keycloak realm. Pre-install writes the realm from the template using `JUPYTERHUB_CLIENT_SECRET`, `NEXTCLOUD_CLIENT_SECRET`, `SCS_MANAGER_CLIENT_SECRET`, and `KC_DIDMOS_CLIENT_SECRET`. If the realm was imported before these were set, re-run the Keycloak pre-install script or update each client’s secret in Keycloak Admin (Clients → &lt;client&gt; → Credentials).

- [ ] **Groups for JupyterHub and WissKI** — The realm defines group `/wisski_admin` (in `00_custom_configs/keycloak/templates/realm/scs-realm.json.tpl`). JupyterHub uses `KC_USER_GROUPS` (e.g. `user`) and `KC_ADMIN_GROUPS` from `.env` to decide who can log in and who is admin. Ensure users who should access JupyterHub are in the allowed group(s); put WissKI admin users in `wisski_admin`.

- [ ] **`scs_user` group** — Ensure the `scs_user` group exists in Keycloak (Realm → Groups). Create it if missing. Users who should access SCS services (e.g. JupyterHub, SCS Manager) are typically assigned to this group; align with `KC_USER_GROUPS` if JupyterHub is configured to use it.

- [ ] **GID / group mappings** — The realm has a client scope “groups” with mappers for `groups` (oidc-group-membership-mapper) and `gids` (user attribute `gid`, multivalued). JupyterHub’s `auth_state_groups_key` in `jupyterhub/jupyterhub/jupyterhub_config.py` expects `groups` and `gids` in the token. The JupyterHub Keycloak client **does not** include the “groups” scope in its default or optional client scopes in the realm template. For JupyterHub group-based access and spawner gids to work:
  - In Keycloak Admin: Realm → Clients → &lt;JupyterHub client&gt; → Client scopes → add the realm’s **groups** scope as default or optional.
  - If you use gids in the spawner, ensure the “groups” client scope (which includes the gids mapper) is assigned to the JupyterHub client so the token/userinfo contain `gids`.

- [ ] **User attribute `gid`** — If using gids for the JupyterHub spawner, set the `gid` attribute (or multiple values) on users in Keycloak: Users → &lt;user&gt; → Attributes.

---

## SCS Manager

- [ ] **OpenID config** — Pre-install writes `00_custom_configs/scs-manager-stack/openid/openid_connect.client.scs_sso.yml.tpl` to `scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml`. Ensure this config is imported/synced into Drupal (e.g. config sync or install profile). Drupal OpenID behaviour is further tuned in `00_custom_configs/scs-manager-stack/drupal/openid-connect.settings.php`.

- [ ] **Trusted hosts / proxy** — `00_custom_configs/scs-manager-stack/drupal/reverse-proxy.settings.php` and env vars `SCS_MANAGER_DRUPAL_TRUSTED_HOSTS` and `DRUPAL_PROXY_ADDRESSES` must match your deployment (Traefik/proxy and domain).

- [ ] **Docs and settings** — Confirm SCS Manager settings at `/admin/config/soda-scs-manager/settings`. If the product exposes a docs path, ensure the base URL or path is correct.

- [ ] **SMTP config** — Ensure SMTP (outgoing mail) is configured and working in Drupal (e.g. Configuration → System → Basic site settings → SMTP Authentication Support, or the mail system in use). If SMTP is not working, user registration will fail because verification or welcome emails cannot be sent.

- [ ] **WissKI** — Configure WissKI settings with the Portainer API token: endpoint (e.g. `1`), create/read/update/delete stack API URLs (e.g. `https://portainer.&lt;DOMAIN&gt;/api/stacks/...`). See the main README for the exact routes.

---

## Nextcloud

- [ ] **Plugins** — Post-install hooks install Social Login, configure Nextcloud, OnlyOffice, and Draw.io. Verify with `occ app:list` (inside the Nextcloud container) that `sociallogin` (and other expected apps) are enabled. If the hooks did not run, run them manually or install the apps via the Nextcloud UI.

- [ ] **OpenID / Social Login** — Configure the Social Login app with Keycloak:
  - Discovery URL or issuer: `https://&lt;KC_DOMAIN&gt;/realms/&lt;KC_REALM&gt;` (e.g. `https://auth.scs.localhost/realms/main`).
  - Client ID: same as the Nextcloud client in Keycloak (typically the value of `NEXTCLOUD_NEXTCLOUD_DOMAIN`, e.g. `http://drive.scs.localhost` or the domain used as client ID in the realm).
  - Client secret: value of `NEXTCLOUD_CLIENT_SECRET` from `.env`.
  - Redirect URL: must match the Nextcloud domain (e.g. `https://&lt;NEXTCLOUD_DOMAIN&gt;/apps/sociallogin/oidc/callback` or as required by the app).

- [ ] **OnlyOffice / Draw.io** — If the post-install hooks ran, confirm in Nextcloud admin that OnlyOffice and Draw.io are configured. Otherwise document or perform manual configuration.

---

## JupyterHub

- [ ] **Keycloak client** — Client ID and secret come from env (`CLIENT_ID` / `JUPYTERHUB_CLIENT_ID`, `CLIENT_SECRET` / `JUPYTERHUB_CLIENT_SECRET`). Callback and Keycloak URLs are set via env in the compose override. Ensure they match the Keycloak client’s redirect URIs and web origins.

- [ ] **Groups and gids** — Add the Keycloak “groups” scope to the JupyterHub client (see Keycloak section above) so `auth_state_groups_key` receives `groups` and `gids`. Confirm `KC_USER_GROUPS` and `KC_ADMIN_GROUPS` in JupyterHub’s env match Keycloak group names (e.g. `user` for allowed users, and the admin group name for admins).

---

## OpenGDB

- [ ] **AuthProxy** — OpenGDB AuthProxy (and any OIDC/Keycloak integration) is configured per deployment. List or verify any env or config that must be set after first start (e.g. allowed hosts, CORS, OIDC client).

- [ ] **Domain** — `OPEN_GDB_DOMAIN` is used in the nginx template. Ensure trusted hosts and CORS (if applicable) match this domain.

---

## Project website (scs-project-website-stack)

- [ ] **DB and VCL** — Pre-install creates the database and user and generates Varnish VCL from a template. If you run the pre-install manually: the script is in `01_scripts/scs-project-page/pre-install.bash` and references `00_custom_configs/scs-project-website/varnish/default.vcl.tpl`, but the template file is at `00_custom_configs/scs-project-page/varnish/default.vcl.tpl`. Use the path under `scs-project-page` if the script fails. Ensure the generated VCL and DB are in use after startup.

---

## Other services

- [ ] **Portainer** — On first visit, create the admin account. Create an [access token](https://docs.portainer.io/api/access#creating-an-access-token) for SCS Manager/WissKI. Add the GitHub Container Registry (ghcr.io) if you need to pull private images from the UI.

- [ ] **Traefik** — Dashboard and Let’s Encrypt certificates are configured via labels and env. Document or verify `SCS_TRAEFIK_*` (domain, email, basic auth username/hash) and any middleware ordering if relevant for your setup.
