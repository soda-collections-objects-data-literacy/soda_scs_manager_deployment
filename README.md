# SODa SCS Manager Deployment
This repository provides a docker compose environment to orchestrate the deployment of a Drupal-based Content Management System alongside essential services like MariaDB for database management, Portainer for container management, and Traefik as a reverse proxy and SSL certificate manager.

## Version
- SODa SCS Manager Deployment 1.0.0
- Drupal: 11.0
- SODa SCS Manager: Dev
- MariaDB: 11.5
- Portainer Agent:2.21
- Portainer Community Edition: 2.21
- Traefik:3.0

## Overview

The docker-compose.yml file in this repository is structured to deploy the following services:

- SCS Manager Drupal: A Drupal service pre-configured for the SCS Manager, utilizing an image that includes Drupal 11.0.1 with PHP 8.3 and Apache on Debian Bookworm. This service is fully equipped with volume mounts for Drupal's modules, profiles, themes, libraries, and sites directories, ensuring that your customizations and data persist across container restarts.

- MariaDB: A MariaDB database service, which serves as the backend database for the Drupal installation. It is configured with environment variables for secure access and data persistence through a dedicated volume.

- Portainer: A set of services (Portainer CE and Portainer Agent) that provide a user-friendly web UI for managing Docker environments. It's configured to ensure secure access and data persistence, facilitating easy management of your Docker containers, volumes, and networks.

- Traefik: A modern HTTP reverse proxy and load balancer that makes deploying microservices easy. Traefik is used here to manage SSL certificates automatically via Let's Encrypt, route external requests to the appropriate services, and enforce HTTPS redirection. It's configured with HTTP basic authentication for secure access to the dashboard and API.

## Getting Started

### Prerequisites
- [Install docker](https://docs.docker.com/engine/install/).
- **User must be a member of the docker group** to run Docker commands without sudo:
  ```bash
  sudo usermod -aG docker $USER
  # Log out and log back in for the changes to take effect
  ```
### Add GitHub package registry
- Create a [personal access token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) with:
    - [x] read:packages
- [Login to GitHub packages registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic).
### Set environment variables
- Copy `.example-env` to `.env` and set the variables.
- (Use `echo $(htpasswd -nb TRAEFIK_USERNAME TRAEFIK_PASSWORD) | sed -e s/\\$/\\$\\$/g` to generate hashed traefik user password.)
### Initial Setup

**Important Prerequisites:**
1. Ensure your user is a member of the docker group (see Prerequisites above)

Run the starter script to set up everything:
```bash
./start.sh
```

**Note:** The `start.sh` script will automatically:
1. Check that `.env` file exists (exits with error if not found)
2. Ensure Docker network `reverse-proxy` is created
3. Update main repository and all submodules to latest commits
4. Copy docker-compose override files to submodules
5. Start only the database service (required for pre-install scripts)
6. Wait for database to be ready and root user accessible
7. Execute all pre-install scripts to create databases and generate configs

Do not start all services before running `start.sh`, as they depend on databases that will be created during the pre-install phase.
### Single command compose
- The root `.env` includes a `COMPOSE_FILE` list so you can run one command from the repo root.
- Start everything with `docker compose up -d` after creating required networks.

This script will:
- Copy docker-compose override files from `00_custom_configs/` to their respective stack directories
- Execute all pre-install scripts from `01_scripts/` in the correct order:
  1. Global setup (snapshot directory)
  2. Keycloak (database + realm config)
  3. SCS Manager Stack (database + OIDC config)
  4. Nextcloud Stack (database)
  5. Project Page Stack (database)
  6. OpenGDB (nginx config generation)
- Ensure all scripts are executed from the repo root to handle relative paths correctly
- Skip copying files that already exist to prevent overwriting custom configurations

### Build environment
After initial setup, start SCS Manager deployment environment with:
```bash
docker compose up -d
```

**Note:** The OnlyOffice integration for Nextcloud is automatically configured via post-install hooks, so manual configuration is no longer needed.

## SCS Manager config

### Portainer
- Visit `portainer.DOMAIN`.
- [Create access token](https://docs.portainer.io/api/access#creating-an-access-token).
- [Add GitHub packages registry](https://docs.portainer.io/admin/registries/add/ghcr) .
    - choose "Custom registry".
    - Registry URL = ghcr.io/USERNAME.
    - Authentication USERNAME/PASSWORD.
### SCS Manager
- Visit `DOMAIN`.
- Set settings at `/admin/config/soda-scs-manager/settings`.
#### WissKI settings
- Use your Authentication token you have created in section [Portainer](#portainer).
- Endpoint is usually `1` with one node.
- Create route path: `https://portainer.DOMAIN/api/stacks/create/swarm/repository`
- Read one route path: `https://portainer.DOMAIN/api/stacks/`
- Read all route path: `https://portainer.DOMAIN/api/stacks/`
- Update route path: `https://portainer.DOMAIN/api/stacks/`
- Delete route path: `https://portainer.DOMAIN/api/stacks/`

# License

This project is licensed under the GPL v3 License - see the LICENSE file for details.




## Step-by-Step Installation Guide

### Step 1: Clone the Repository
```bash
git clone git@github.com:soda-collections-objects-data-literacy/soda_scs_manager_deployment.git
cd soda_scs_manager_deployment
```

### Step 2: Initialize Submodules
```bash
git submodule update --init --recursive
```

### Step 3: Create and Configure Environment File
```bash
cp example-env .env
nano .env  # Edit and set all required variables
```

**Important variables to set:**
- `SCS_DOMAIN` - Your main domain (e.g., `example.com`)
- `DB_ROOT_PASSWORD` - MariaDB root password
- `SCS_TRAEFIK_HASHED_PASSWORD` - Generate with: `echo $(htpasswd -nb USERNAME PASSWORD) | sed -e s/\\$/\\$\\$/g`
- `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` - Keycloak admin credentials
- `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD` - Nextcloud admin credentials
- `OPEN_GDB_DOMAIN` - OpenGDB domain (e.g., `ts.example.com`)
- All client secrets for OAuth integration (JupyterHub, Nextcloud, SCS Manager, DIDMOS)

### Step 4: Setup Submodule-Specific Configuration (Optional)
If submodules require their own `.env` files:

**JupyterHub:**
```bash
cd jupyterhub
cp .env.example .env
cp .secret.env.sample .secret.env
nano .env         # Configure JupyterHub settings
nano .secret.env  # Configure OAuth secrets
cd ..
```

**WebProtégé:**
```bash
cd webprotege
# Clone if needed: git clone git@github.com:protegeproject/webprotege.git .
cd ..
```

### Step 5: Run Initial Setup Script
```bash
./start.sh
```

**Note:** The `start.sh` script performs all necessary setup automatically. You don't need to create networks or start services manually.

This script performs the following automated setup:

**Step 0: Check Prerequisites**
- Verifies `.env` file exists (exits with error if not found)
- Loads environment variables from `.env`

**Step 1: Ensure Docker Network**
- Creates Docker network `reverse-proxy` if it doesn't exist
- Skips if network already exists

**Step 2: Update Git Repositories**
- Pulls latest changes from main repository
- Initializes submodules if needed
- Updates all submodules to latest commits

**Step 3: Copy Override Files**
- Copies docker-compose override files from `00_custom_configs/` to their respective stack directories:
  - `scs-manager-stack/docker-compose.override.yml`
  - `scs-nextcloud-stack/docker-compose.override.yml`
  - `scs-project-page-stack/docker-compose.override.yml`
  - `jupyterhub/docker-compose.override.yml`
  - `keycloak/docker-compose.override.yml`
- Skips files that already exist to prevent overwriting custom configurations

**Step 4: Start Database Service**
- Starts only the database service (not all services)
- Skips if database is already running

**Step 5: Wait for Database Ready**
- Waits for database container to be running
- Verifies database accepts connections
- Confirms root user is accessible and database is healthy
- Times out after 60 attempts (2 minutes) with warning

**Step 6: Execute Pre-Install Scripts**

Executes the following pre-install scripts in order:

1. **`01_scripts/global/pre-install.bash`**
   - Creates snapshot directory `/var/backups/scs-manager/snapshots`
   - Sets proper permissions for www-data user

2. **`01_scripts/keycloak/pre-install.bash`**
   - Validates required environment variables
   - Creates Keycloak database and user in MariaDB
   - Generates Keycloak realm configuration file from template (`scs-realm.json`)

3. **`01_scripts/scs-manager-stack/pre-install.bash`**
   - Creates SCS Manager database and user in MariaDB
   - Generates OpenID Connect client configuration file

4. **`01_scripts/scs-nextcloud-stack/pre-install.bash`**
   - Creates Nextcloud database and user in MariaDB

5. **`01_scripts/scs-project-page/pre-install.bash`**
   - Creates project page database and user in MariaDB
   - Optionally loads sammlungen.io specific variables if present

6. **`01_scripts/open_gdb/pre-install.bash`**
   - Validates `OPEN_GDB_DOMAIN` environment variable
   - Generates OpenGDB nginx configuration from template

### Step 7: Start All Services
Now that all databases have been created by the pre-install scripts, you can start all services:

```bash
docker compose up -d
```

**Note:** The database service is already running from `start.sh`, so only other services will be started.

Or use the convenience script:
```bash
./01_scripts/global/pre-install.bash  # Ensures snapshot directory exists
docker compose up -d
```

### Step 8: Verify Services Are Running
```bash
docker compose ps
```

Check logs if needed:
```bash
docker compose logs -f [service-name]
```

### Step 9: Setup Admin Accounts

**Keycloak:**
- Visit `https://auth.${SCS_DOMAIN}`
- Login with `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` from `.env`
- Configure OAuth clients and secrets as needed

**Nextcloud:**
- Visit `https://nextcloud.${SCS_DOMAIN}`
- Login with `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD` from `.env`
- OnlyOffice integration is automatically configured via post-install hooks

**Portainer:**
- Visit `https://portainer.${SCS_DOMAIN}`
- Create admin account on first visit
- [Create access token](https://docs.portainer.io/api/access#creating-an-access-token)
- [Add GitHub packages registry](https://docs.portainer.io/admin/registries/add/ghcr) if needed

**OpenGDB:**
- Visit `https://${OPEN_GDB_DOMAIN}/admin`
- Login with Django admin credentials from `.env` (`DJANGO_SUPERUSER_NAME` / `DJANGO_SUPERUSER_PASSWORD`)

**JupyterHub:**
- Visit `https://jupyterhub.${SCS_DOMAIN}`
- Uses Keycloak OAuth for authentication

**SCS Manager:**
- Visit `https://${SCS_DOMAIN}`
- Configure at `/admin/config/soda-scs-manager/settings`
- Set up WissKI settings with Portainer API token

## Service Stacks

### Main Stack (`./docker-compose.yml`)
- SCS Manager (Drupal)
- MariaDB Database
- Portainer
- Traefik
- Adminer

### Keycloak Stack (`./keycloak/docker-compose.yml`)
- Keycloak identity and access management server
- OAuth/OIDC provider for JupyterHub and other services
- Uses parent stack's MariaDB database
- Integrated with Traefik for reverse proxy

See `keycloak/README.md` for detailed Keycloak stack documentation.

### JupyterHub Stack (`./jupyterhub/docker-compose.yml`)
- JupyterHub server with OAuth
- Spawner image builder
- Per-user Jupyter notebooks

See `jupyterhub/INTEGRATION.md` for detailed JupyterHub stack documentation.

### Nextcloud Stack (`./scs-nextcloud-stack/docker-compose.yml`)
- Nextcloud FPM
- OnlyOffice Document Server
- Nginx reverse proxies
- Redis cache

See `scs-nextcloud-stack/README.md` for detailed Nextcloud stack documentation.

### OpenGDB Stack (`./open_gdb/docker-compose.yml`)
- RDF4J Triplestore
- AuthProxy (Django-based authentication)
- OutProxy (Outgoing request filtering)
- Nginx reverse proxy

See `open_gdb/README.md` for detailed OpenGDB stack documentation.



## Pre-Install Scripts Reference

The `start.sh` script executes the following pre-install scripts automatically. Each script can also be run manually if needed:

### `01_scripts/global/pre-install.bash`
- **Purpose:** Sets up global infrastructure requirements
- **Actions:**
  - Creates `/var/backups/scs-manager/snapshots` directory
  - Sets proper permissions for www-data user
- **Requirements:** None (uses sudo for directory creation)

### `01_scripts/keycloak/pre-install.bash`
- **Purpose:** Prepares Keycloak identity provider
- **Actions:**
  - Validates required environment variables (SCS_DB_ROOT_PASSWORD, KC_*, JUPYTERHUB_*, NEXTCLOUD_*, SCS_MANAGER_*)
  - Creates Keycloak database (`KC_DB_NAME`) and user (`KC_DB_USERNAME`)
  - Generates Keycloak realm configuration from template (`keycloak/keycloak/import/scs-realm.json`)
- **Requirements:**
  - MariaDB database container must be running
  - User must be a member of the docker group

### `01_scripts/scs-manager-stack/pre-install.bash`
- **Purpose:** Prepares SCS Manager Drupal stack
- **Actions:**
  - Creates SCS Manager database (`SCS_MANAGER_DB_NAME`) and user (`SCS_MANAGER_DB_USER`)
  - Generates OpenID Connect client configuration file for SSO integration
- **Requirements:**
  - MariaDB database container must be running
  - User must be a member of the docker group

### `01_scripts/scs-nextcloud-stack/pre-install.bash`
- **Purpose:** Prepares Nextcloud stack
- **Actions:**
  - Creates Nextcloud database (`NEXTCLOUD_DB_NAME`) and user (`NEXTCLOUD_DB_USER`)
- **Requirements:**
  - MariaDB database container must be running
  - User must be a member of the docker group

### `01_scripts/scs-project-page/pre-install.bash`
- **Purpose:** Prepares project page stack
- **Actions:**
  - Creates project page database (`PROJECT_WEBSITE_DB_NAME`) and user (`PROJECT_WEBSITE_DB_USER`)
  - Optionally loads sammlungen.io specific environment variables if present
- **Requirements:**
  - MariaDB database container must be running
  - User must be a member of the docker group

### `01_scripts/open_gdb/pre-install.bash`
- **Purpose:** Prepares OpenGDB triplestore stack
- **Actions:**
  - Validates `OPEN_GDB_DOMAIN` environment variable
  - Generates nginx configuration file from template (`open_gdb/opengdb_proxy/nginx.conf`)
- **Requirements:** Template file must exist at `00_custom_configs/open_gdb/opengdb_proxy/nginx.conf.tpl`

## Troubleshooting

### Pre-Install Script Failures
If a pre-install script fails:
1. **Check if database container is running:** `docker compose ps database` or `docker ps | grep database`
   - The `start.sh` script should have started it automatically
   - If not running, start it manually: `docker compose up -d database`
   - Check database logs: `docker compose logs database`
2. Check the error message for missing environment variables
3. Verify `.env` file contains all required variables (especially `SCS_DB_ROOT_PASSWORD`)
4. Ensure your user is a member of the docker group: `groups | grep docker`
5. Check script permissions: `chmod +x 01_scripts/*/pre-install.bash`
6. Check Docker socket permissions if you see "permission denied" errors

### Override Files Not Copied
If override files are skipped:
- The script protects existing files from being overwritten
- To update override files, manually delete the destination file and re-run `./start.sh`
- Or manually copy: `cp 00_custom_configs/[stack]/docker/docker-compose.override.yml [stack]/docker-compose.override.yml`

### Database Connection Issues
- Ensure MariaDB container is running: `docker compose ps database`
- Verify database credentials in `.env` match what's expected
- Check database logs: `docker compose logs database`

### Submodule Issues
If submodules are not initialized:
```bash
git submodule update --init --recursive
```

If a submodule commit is missing:
```bash
cd [submodule-name]
git fetch origin
git checkout main  # or master
git pull
cd ..
git add [submodule-name]
```

## Keycloak Configuration
Comes with several client connections pre-configured:
- JupyterHub OAuth client
- Nextcloud OAuth client
- SCS Manager OAuth client
- DIDMOS client (requires manual secret configuration after installation)

### Secrets
Client secrets need to be added after installation for:
- DIDMOS: Configure `KC_DIDMOS_CLIENT_SECRET` in Keycloak admin console
