# Initial setup

This section describes what must be done **before** the first `docker compose up` so that the deployment starts correctly.

## Overview

The deployment expects:

1. **Prerequisites** — Docker installed and your user in the `docker` group; GitHub authentication for pulling images (ghcr.io) and for Git/submodules; a configured `.env` file.
2. **Pre-start steps** — Run `./start.sh` (or perform its steps manually). This creates the Docker network, copies override files, starts only the shared database, waits for it to be ready, and runs all pre-install scripts. Pre-install scripts create databases and users, and generate config files from templates (e.g. Keycloak realm, SCS Manager OpenID config, Varnish VCL).

**Important:** Do not run a full `docker compose up -d` until after `start.sh` has completed successfully. Otherwise databases and generated configs will be missing and services will fail or behave incorrectly.

## Steps

1. **[Prerequisites](prerequisites.md)** — Install Docker, configure GitHub access, copy and edit `.env`.
2. **[Pre-start steps](pre-start-steps.md)** — Run `./start.sh` and understand what it does (network, overrides, database, pre-install scripts).
3. After that, run `docker compose up -d` to start all services.
4. Then follow the [Post-configuration checklist](../post-configuration/checklist.md) to configure each service (Keycloak, SCS Manager, Nextcloud, JupyterHub, etc.).

## Required environment variables (Keycloak pre-install)

The Keycloak pre-install script validates that these variables are set and non-empty (see `01_scripts/keycloak/pre-install.bash`):

- `SCS_DB_ROOT_PASSWORD`
- `JUPYTERHUB_CLIENT_SECRET`, `JUPYTERHUB_DOMAIN`
- `KC_DB_NAME`, `KC_DB_PASSWORD`, `KC_DB_USERNAME`, `KC_REALM`
- `KC_DIDMOS_CLIENT_ID`, `KC_DIDMOS_CLIENT_SECRET`
- `NEXTCLOUD_CLIENT_SECRET`, `NEXTCLOUD_NEXTCLOUD_DOMAIN`
- `SCS_MANAGER_CLIENT_SECRET`, `SCS_MANAGER_DOMAIN`

Set them in `.env` before running `start.sh` so the generated Keycloak realm and client secrets are correct from the first start. See [Prerequisites](prerequisites.md) and `example-env` for the full list of variables.
