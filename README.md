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
### Init docker swarm 
- Init docker swarm with `docker swarm init`.
- Add reverse proxy constraints to node with `docker node update --label-add reverse-proxy.reverse-proxy-certificates=true <node-id>`. (Get your `<node-id>` with `docker node inspect self`).
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
- Retrieve the Swarm Id with `docker info | grep NodeID`.
- Endpoint is usually `1` with one node.
- Create route path: `https://portainer.DOMAIN/api/stacks/create/swarm/repository`
- Read one route path: `https://portainer.DOMAIN/api/stacks/`
- Read all route path: `https://portainer.DOMAIN/api/stacks/`
- Update route path: `https://portainer.DOMAIN/api/stacks/`
- Delete route path: `https://portainer.DOMAIN/api/stacks/`

# License

This project is licensed under the GPL v3 License - see the LICENSE file for details.