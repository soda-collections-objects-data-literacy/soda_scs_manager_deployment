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
### Set environment variables
- Copy `.example-env` to `.env` and set the variables.
- (Use `echo $(htpasswd -nb TRAEFIK_USERNAME TRAEFIK_PASSWORD) | sed -e s/\\$/\\$\\$/g` to generate hashed traefik user password.)
### Add GitHub package registry
- Create a [personal access token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) with:
    - [x] read:packages
- [Login to GitHub packages registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic).
### Build environment
Start SCS Manager ceployment environment with `./start.sh`.
### Create Portainer admin
Visit `portainer.DOMAIN` and create admin account.

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




## Quick Start Guide

1. Clone the repository:
```bash
git clone git@github.com:soda-collections-objects-data-literacy/soda_scs_manager_deployment.git
cd soda_scs_manager_deployment
```

2. Create and configure `.env` file:
```bash
cp .example-env .env
nano .env  # Set your passwords and domain
```

3. Setup JupyterHub:
```bash
cd jupyterhub
git clone git@github.com:soda-collections-objects-data-literacy/jupyterhub.git .
cp .env.example .env
cp .secret.env.sample .secret.env
nano .env         # Configure JupyterHub settings
nano .secret.env  # Configure OAuth secrets
cd ..
```

4. Setup WebProtégé:
```bash
cd webprotege
git clone git@github.com:protegeproject/webprotege.git .
cd ..
```

5. Setup Nextcloud stack:
```bash
cd scs-nextcloud-stack
cp .env.example .env
nano .env  # Configure Nextcloud settings
cd ..
```

6. Create Docker networks:
```bash
docker network create reverse-proxy
```

7. Start main services (database, Traefik, SCS Manager, etc.):
```bash
docker compose up -d database traefik  # Start these first
sleep 10
docker compose up -d                   # Start remaining services
```

8. Create Keycloak database:
```bash
bash scripts/keycloak/pre-install.sh
```

9. Start Keycloak stack:
```bash
cd keycloak
docker compose up -d
cd ..
```

10. Start JupyterHub stack:
```bash
cd jupyterhub
docker compose up -d
cd ..
```

11. Create Nextcloud databases:
```bash
bash scripts/nextcloud/create-databases.bash
```

12. Start Nextcloud stack:
```bash
cd scs-nextcloud-stack
docker compose up -d
cd ..
```

13. Start OpenGDB stack:
```bash
cd open_gdb
cp .env.example .env
nano .env  # Configure OpenGDB settings
docker compose up -d
cd ..
```

14. Configure OnlyOffice integration:
```bash
bash scripts/nextcloud/only-office.bash
```

15. Setup admin accounts:
    - Keycloak: Visit `https://auth.${SCS_DOMAIN}` (uses KC_BOOTSTRAP_ADMIN_USERNAME/PASSWORD from .env)
    - Nextcloud: Visit `https://nextcloud.${SCS_DOMAIN}` and create admin
    - Portainer: Visit `https://portainer.${SCS_DOMAIN}` and create admin
    - OpenGDB: Visit `https://ts.${SCS_DOMAIN}/admin` (uses Django admin credentials from .env)
    - JupyterHub: Visit `https://jupyterhub.${SCS_DOMAIN}` (uses Keycloak OAuth)

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
