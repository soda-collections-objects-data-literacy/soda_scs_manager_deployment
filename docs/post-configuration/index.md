# Post-configuration

After the whole environment has started with `docker compose up -d`, many services still need one-time or periodic configuration inside their UIs or config. This section gives an overview and links to the detailed checklist.

## Overview

- **Keycloak** — Client secrets must match `.env`; groups (e.g. for JupyterHub and WissKI) and GID mappings must be correct; the JupyterHub client may need the “groups” (and “gids”) scope added for group-based access and spawner gids.
- **SCS Manager** — OpenID Connect config must be in place (from pre-install); trusted hosts and reverse proxy settings must match the deployment; SCS Manager and WissKI settings (e.g. Portainer API token) must be configured.
- **Nextcloud** — Plugins (Social Login, OnlyOffice, Draw.io) must be installed and enabled; Social Login must be configured with Keycloak (realm URL, client ID, client secret, redirect URL).
- **JupyterHub** — Keycloak client ID and secret are from env; ensure the JupyterHub client in Keycloak has the “groups” (and optionally “gids”) scope so group-based access and spawner gids work; `KC_USER_GROUPS` and `KC_ADMIN_GROUPS` must match Keycloak group names.
- **phpMyAdmin/DBMS** — Keycloak SSO with per-user `mariadb_password`; no pre-installed DB users; SCS Manager creates MariaDB users and syncs passwords to Keycloak when users create SQL components.
- **OpenGDB, project website, Portainer, Traefik** — Domain, trusted hosts, admin accounts, and optional settings as described in the checklist.

## Checklist

Use the [Post-configuration checklist](checklist.md) for a service-by-service list of what to verify and configure after the stack is running. It covers Keycloak, SCS Manager, Nextcloud, JupyterHub, phpMyAdmin/DBMS, OpenGDB, project website, Portainer, and Traefik.

For more detail on specific services, see also the main [README](../../README.md) (e.g. Portainer access token, SCS Manager settings, WissKI/Portainer API, Nextcloud admin).

## Keycloak and Nextcloud Integration

For a step-by-step guide on configuring Keycloak and Nextcloud for SSO and Bearer token validation (including cross-client token sharing for WissKI/WebDAV), see [Keycloak and Nextcloud](keycloak-nextcloud.md).
