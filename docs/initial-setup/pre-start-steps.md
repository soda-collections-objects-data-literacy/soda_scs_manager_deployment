# Pre-start steps

The script `start.sh` at the repository root performs all setup that must happen before the first full `docker compose up`. Run it from the repo root after [prerequisites](prerequisites.md) are met:

```bash
./start.sh
```

## What `start.sh` does

### Step 0: Check prerequisites

- Verifies that a `.env` file exists in the repo root (exits with an error if not).
- Loads environment variables from `.env`.

### Step 1: Ensure Docker network exists

- Creates the Docker network `reverse-proxy` if it does not exist.
- All stacks attach to this network so Traefik can route to them.

### Step 2: Update Git repositories and submodules

- Runs `git pull` on the main repository.
- Runs `git submodule update --init --recursive` and then `git submodule update --remote --recursive` to bring submodules up to date.

### Step 3: Copy docker-compose override files

Copies override files from `00_custom_configs/` into each stack directory. The mapping (as in `start.sh`) is:

| Source | Destination |
|--------|-------------|
| `00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml` | `scs-manager-stack/docker-compose.override.yml` |
| `00_custom_configs/scs-nextcloud-stack/docker/docker-compose.override.yml` | `scs-nextcloud-stack/docker-compose.override.yml` |
| `00_custom_configs/scs-project-website/docker/docker-compose.override.yml` | `scs-project-website-stack/docker-compose.override.yml` |
| `00_custom_configs/jupyterhub/docker/docker-compose.override.yml` | `jupyterhub/docker-compose.override.yml` |
| `00_custom_configs/keycloak/docker/docker-compose.override.yml` | `keycloak/docker-compose.override.yml` |
| `00_custom_configs/open_gdb/docker/docker-compose.override.yml` | `open_gdb/docker-compose.override.yml` |

If a destination file already exists, the script skips copying to avoid overwriting local changes.

**Note:** The source path for the project website uses `scs-project-website`; the actual config directory may be `00_custom_configs/scs-project-page/`. If the copy fails, check that the source path exists or adjust the script.

### Step 4: Start database service

- Starts only the main stack database service: `scs--database` (MariaDB).
- Uses `COMPOSE_FILE=docker-compose.yml` so only the main compose file is loaded (avoids loading submodule compose files that might depend on env vars not yet set).
- Skips if the database container is already running.

### Step 5: Wait for database to be ready

- Waits until the database container is running and accepts connections.
- Verifies that the root user can connect (using `SCS_DB_ROOT_PASSWORD` from `.env`).
- Retries up to 60 times with 2-second intervals. If the database is still not ready, the script continues with a warning.

### Step 6: Execute pre-install scripts

Runs the following scripts in order from the repo root. Each script is executed with `bash`; if any script fails, `start.sh` exits.

| Script | Purpose |
|--------|---------|
| `01_scripts/global/pre-install.bash` | Creates snapshot directory `/var/backups/scs-manager/snapshots` and sets permissions for www-data. |
| `01_scripts/jupyterhub/pre-install.bash` | Downloads and extracts OpenRefine (or similar assets). **Note:** The script on disk may be named `pre-install.sh`; `start.sh` references `pre-install.bash`. If the script is missing, run the `.sh` variant or fix the path in `start.sh`. |
| `01_scripts/keycloak/pre-install.bash` | Validates required env vars; creates Keycloak database and user in MariaDB; generates Keycloak realm file from `00_custom_configs/keycloak/templates/realm/scs-realm.json.tpl` into `keycloak/keycloak/import/scs-realm.json`. |
| `01_scripts/scs-manager-stack/pre-install.bash` | Creates SCS Manager database and user; generates OpenID Connect client config from template into `scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml`; generates Varnish VCL from template. |
| `01_scripts/scs-nextcloud-stack/pre-install.bash` | Creates Nextcloud database and user in MariaDB. |
| `01_scripts/scs-project-website/pre-install.bash` | Creates project website database and user; generates Varnish VCL from template. **Note:** The script directory is actually `01_scripts/scs-project-page/` (not `scs-project-website`). If `start.sh` reports "Pre-install script not found", run `01_scripts/scs-project-page/pre-install.bash` manually or fix the path in `start.sh`. The script itself references `00_custom_configs/scs-project-website/varnish/default.vcl.tpl`; the template file is under `00_custom_configs/scs-project-page/varnish/default.vcl.tpl`. |
| `01_scripts/open_gdb/pre-install.bash` | Validates `OPEN_GDB_DOMAIN`; generates OpenGDB nginx config from `00_custom_configs/open_gdb/opengdb_proxy/nginx.conf.tpl` into `open_gdb/opengdb_proxy/nginx.conf`. |

All scripts expect `.env` to be loaded (they source it if present). They use `docker exec scs--database` for DB operations, so the database must be running (Step 4) and ready (Step 5).

## After `start.sh` completes

1. Start all services:
   ```bash
   docker compose up -d
   ```
   (Ensure `COMPOSE_FILE` is set, e.g. from `.env` or `example-env`.)

2. Follow the [Post-configuration checklist](../post-configuration/checklist.md) to configure Keycloak, SCS Manager, Nextcloud, JupyterHub, and other services.
