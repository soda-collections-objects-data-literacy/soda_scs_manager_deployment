# Prerequisites

Before running the deployment, ensure the following are in place.

## Docker

- [Install Docker](https://docs.docker.com/engine/install/) on the host.
- Your user must be a member of the `docker` group so you can run Docker commands without `sudo`:
  ```bash
  sudo usermod -aG docker $USER
  ```
  Log out and log back in for the change to take effect.

## GitHub authentication

The deployment needs GitHub for two purposes:

1. **Docker** — Pulling private container images from GitHub Container Registry (ghcr.io), e.g. `ghcr.io/fau-cdi/open_gdb_authproxy`.
2. **Git** — Cloning the repository and updating submodules.

### Docker login to ghcr.io

1. Create a [GitHub Personal Access Token (classic)](https://github.com/settings/tokens) with at least the `read:packages` scope.
2. Log in:
   ```bash
   docker login ghcr.io
   ```
   Use your GitHub username and the token as the password.
3. Verify: `docker pull ghcr.io/fau-cdi/open_gdb_authproxy:latest` (or another image you use) should succeed.

### Git authentication

- **SSH (recommended):** Add your SSH key to GitHub and clone/pull using SSH URLs (`git@github.com:...`).
- **HTTPS:** Use a Personal Access Token when Git prompts for a password.

After cloning, run `git submodule update --init --recursive`; `start.sh` also updates submodules.

## Environment file (`.env`)

1. Copy the example environment file:
   ```bash
   cp example-env .env
   ```
2. Edit `.env` and set all required variables. Important ones include:
   - **Database:** `SCS_DB_ROOT_PASSWORD`
   - **Keycloak:** `KC_*` (database, realm, admin credentials), and client secrets for JupyterHub, Nextcloud, SCS Manager, DIDMOS (`JUPYTERHUB_CLIENT_SECRET`, `NEXTCLOUD_CLIENT_SECRET`, `SCS_MANAGER_CLIENT_SECRET`, `KC_DIDMOS_CLIENT_SECRET`).
   - **Domains:** e.g. `SCS_BASE_DOMAIN`, `SCS_SUBDOMAIN`, `JUPYTERHUB_DOMAIN`, `NEXTCLOUD_NEXTCLOUD_DOMAIN`, `SCS_MANAGER_DOMAIN`, `KC_DOMAIN`, `OPEN_GDB_DOMAIN`.
   - **Traefik:** `SCS_TRAEFIK_EMAIL`, `SCS_TRAEFIK_HASHED_PASSWORD`, `SCS_TRAEFIK_USERNAME` (for dashboard basic auth). Generate the hash with: `echo $(htpasswd -nb USERNAME PASSWORD) | sed -e s/\\$/\\$\\$/g`
   - **Nextcloud:** `NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD`, `NEXTCLOUD_DB_*`, `NEXTCLOUD_CLIENT_SECRET`.
   - **JupyterHub:** `JUPYTERHUB_CLIENT_SECRET`, `KC_USER_GROUPS`, `KC_ADMIN_GROUPS`.
   - **OpenGDB:** `OPEN_GDB_DOMAIN`, `DJANGO_*` (secret, superuser, etc.).

See `example-env` and the main [README](../../README.md) for the full list. The Keycloak pre-install script checks a subset of these (see [Initial setup overview](index.md#required-environment-variables-keycloak-pre-install)).

## Optional: submodule-specific `.env` files

Some submodules may expect their own `.env` in their directory (e.g. JupyterHub: `jupyterhub/.env`, `jupyterhub/secret.env`). Copy from the provided samples and set values as needed. The main `docker compose` run is driven from the repo root with the root `.env` and `COMPOSE_FILE` from `example-env`.
