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
### Authenticate with GitHub

This deployment requires authentication with GitHub for two purposes:
1. **Docker:** Pulling private container images from GitHub Container Registry (ghcr.io)
2. **Git:** Cloning repositories and updating submodules

#### Docker Login to GitHub Container Registry (ghcr.io)

**Purpose:** Required to pull private Docker images from `ghcr.io` (e.g., `ghcr.io/fau-cdi/open_gdb_authproxy`).

**Step 1: Create a GitHub Personal Access Token (PAT)**

1. Navigate to GitHub token settings:
   - Direct link: [GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)](https://github.com/settings/tokens)
   - Or manually: GitHub → Your profile (top right) → Settings → Developer settings → Personal access tokens → Tokens (classic)

2. Generate a new token:
   - Click "Generate new token (classic)"
   - Give it a descriptive name (e.g., "Docker ghcr.io access")
   - Set expiration (recommended: 90 days or custom)
   - **Select scopes:**
     - [x] `read:packages` (required for pulling container images)
     - Optionally: `write:packages` (if you need to push images)

3. Generate and copy the token:
   - Click "Generate token" at the bottom
   - **Important:** Copy the token immediately - you won't be able to see it again!
   - Store it securely (password manager recommended)

**Step 2: Login to ghcr.io (Interactive Method)**

1. Run the Docker login command:
   ```bash
   docker login ghcr.io
   ```

2. When prompted, enter:
   - **Username:** Your GitHub username (e.g., `yourusername`)
   - **Password:** Paste your GitHub Personal Access Token (PAT) from Step 1

3. Verify successful login:
   ```bash
   docker login ghcr.io
   # Should show: "Login Succeeded"
   ```

**Step 3: Alternative - Non-Interactive Login (for Scripts)**

If you need to automate login (e.g., in CI/CD or scripts):

1. Set your GitHub token as an environment variable:
   ```bash
   export GITHUB_TOKEN="your_pat_token_here"
   ```

2. Login using the token:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```

3. Verify:
   ```bash
   docker pull ghcr.io/fau-cdi/open_gdb_authproxy:latest
   # Should pull successfully without authentication errors
   ```

**Troubleshooting Docker Login:**
- **Error: "unauthorized: authentication required"**
  - Verify your PAT has `read:packages` scope
  - Check that you're using your GitHub username (not email) as the username
  - Ensure the token hasn't expired
- **Error: "permission denied while trying to connect to the Docker daemon socket"**
  - Ensure your user is in the docker group (see Prerequisites above)
  - Restart your IDE/terminal session after adding user to docker group

#### Git Authentication with GitHub

**Purpose:** Required to clone repositories, pull updates, and update Git submodules.

**Option 1: SSH Authentication (Recommended for Development)**

SSH keys provide secure, passwordless authentication and are the preferred method for development environments.

**Step 1: Check for Existing SSH Keys**

1. List existing SSH public keys:
   ```bash
   ls -la ~/.ssh/id_*.pub
   ```

2. If you see files like `id_ed25519.pub` or `id_rsa.pub`, you already have SSH keys. Skip to Step 3.
   - If you want to use an existing key, proceed to Step 3
   - If you want to create a new key, proceed to Step 2

**Step 2: Generate a New SSH Key**

1. Generate an Ed25519 SSH key (recommended, more secure than RSA):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
   - Replace `your_email@example.com` with your actual email address
   - When prompted for file location, press Enter to use default (`~/.ssh/id_ed25519`)
   - When prompted for passphrase:
     - Option A: Enter a passphrase for extra security (recommended)
     - Option B: Press Enter twice for no passphrase (less secure, but convenient)

2. Start the SSH agent:
   ```bash
   eval "$(ssh-agent -s)"
   ```

3. Add your SSH key to the agent:
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```
   - If you set a passphrase, you'll be prompted to enter it

**Step 3: Add SSH Key to GitHub**

1. Display your public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   - Copy the entire output (starts with `ssh-ed25519` and ends with your email)

2. Add the key to GitHub:
   - Navigate to [GitHub Settings > SSH and GPG keys](https://github.com/settings/keys)
   - Click "New SSH key" button
   - Fill in:
     - **Title:** Descriptive name (e.g., "My Laptop - Development")
     - **Key type:** Authentication Key (default)
     - **Key:** Paste your public key from Step 3.1
   - Click "Add SSH key"
   - Confirm with your GitHub password if prompted

**Step 4: Test SSH Connection**

1. Test the connection:
   ```bash
   ssh -T git@github.com
   ```

2. Expected output:
   - First time: You'll see a message about authenticity of host - type `yes` and press Enter
   - Success: `Hi username! You've successfully authenticated, but GitHub does not provide shell access.`
   - If you see this, SSH authentication is working correctly

**Step 5: Configure Git to Use SSH**

1. Verify your repository uses SSH URL:
   ```bash
   git remote -v
   ```
   - Should show URLs starting with `git@github.com:` (not `https://github.com/`)

2. If your repository uses HTTPS, change it to SSH:
   ```bash
   git remote set-url origin git@github.com:username/repository-name.git
   ```
   - Replace `username/repository-name` with your actual repository path

**Option 2: HTTPS with Personal Access Token**

Use HTTPS authentication if SSH is not available or preferred.

**Step 1: Create a GitHub Personal Access Token (PAT)**

1. Navigate to [GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)](https://github.com/settings/tokens)

2. Generate a new token:
   - Click "Generate new token (classic)"
   - Name: "Git HTTPS Authentication"
   - Expiration: Set as needed
   - **Select scopes:**
     - [x] `repo` (full control of private repositories)
       - This includes: `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`
     - [x] `read:packages` (if you also need Docker registry access)

3. Generate and copy the token (store it securely)

**Step 2: Configure Git Credential Helper**

1. Configure Git to store credentials:
   ```bash
   git config --global credential.helper store
   ```
   - This stores credentials in `~/.git-credentials` (plain text - keep secure!)

2. Alternative: Use cache (credentials expire after 15 minutes):
   ```bash
   git config --global credential.helper cache
   ```

3. Set cache timeout (optional, for cache helper):
   ```bash
   git config --global credential.helper 'cache --timeout=3600'
   ```
   - Sets timeout to 1 hour (3600 seconds)

**Step 3: Configure Git User Information**

1. Set your name and email (required for commits):
   ```bash
   git config --global user.name "Your Full Name"
   git config --global user.email "your_email@example.com"
   ```

2. Verify configuration:
   ```bash
   git config --global --list | grep user
   ```

**Step 4: Test HTTPS Authentication**

1. Clone a repository or pull updates:
   ```bash
   git pull
   # or
   git clone https://github.com/username/repository.git
   ```

2. When prompted for credentials:
   - **Username:** Your GitHub username
   - **Password:** Paste your GitHub Personal Access Token (PAT) from Step 1
   - **Note:** Do NOT use your GitHub account password - use the PAT!

3. Verify credentials are stored (if using store helper):
   ```bash
   cat ~/.git-credentials
   ```
   - Should show: `https://username:token@github.com`

**Troubleshooting Git Authentication:**

- **SSH Issues:**
  - **"Permission denied (publickey)"**
    - Verify SSH key is added to GitHub: `cat ~/.ssh/id_ed25519.pub` matches what's on GitHub
    - Test connection: `ssh -T git@github.com`
    - Check SSH agent: `ssh-add -l` (should list your key)
  - **"Host key verification failed"**
    - Remove old GitHub host key: `ssh-keygen -R github.com`
    - Reconnect and accept new host key

- **HTTPS Issues:**
  - **"Authentication failed"**
    - Verify you're using PAT (not password) as the password
    - Check PAT hasn't expired and has `repo` scope
    - Clear stored credentials: `rm ~/.git-credentials` and try again
  - **"Repository not found"**
    - Verify PAT has `repo` scope
    - Check repository URL is correct
    - Ensure you have access to the repository

**Verification Checklist:**

After completing authentication, verify everything works:

1. **Docker:**
   ```bash
   docker pull ghcr.io/fau-cdi/open_gdb_authproxy:latest
   ```

2. **Git SSH:**
   ```bash
   ssh -T git@github.com
   git pull
   ```

3. **Git HTTPS:**
   ```bash
   git pull
   # Should work without prompting for credentials
   ```
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
  - `scs-project-website-stack/docker-compose.override.yml`
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

5. **`01_scripts/scs-project-website/pre-install.bash`**
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

### `01_scripts/scs-project-website/pre-install.bash`
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
1. **Check if database container is running:** `docker compose ps scs--database` or `docker ps | grep scs--database`
   - The `start.sh` script should have started it automatically
   - If not running, start it manually: `docker compose up -d scs--database`
   - Check database logs: `docker compose logs scs--database`
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
- Ensure MariaDB container is running: `docker compose ps scs--database`
- Verify database credentials in `.env` match what's expected
- Check database logs: `docker compose logs scs--database`

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




# POST-INSTALL
