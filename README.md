# SODa SCS Manager Deployment
This repository provides a docker compose environment to orchestrate the deployment of a Drupal-based Content Management System alongside essential services like MariaDB for database management, Portainer for container management, and Traefik as a reverse proxy and SSL certificate manager.

## Version
- SODa SCS Manager Deployment 1.0.0
- Drupal: 11.0.1
- SODa SCS Manager: Dev
- MariaDB: 11.5.2
- Portainer Agent:2.20.1
- Portainer Community Edition: 2.20.3
- Traefik:3.1.2

## Overview

The docker-compose.yml file in this repository is structured to deploy the following services:

- SCS Manager Drupal: A Drupal service pre-configured for the SCS Manager, utilizing an image that includes Drupal 10.0.1 with PHP 8.3 and Apache on Debian Bookworm. This service is fully equipped with volume mounts for Drupal's modules, profiles, themes, libraries, and sites directories, ensuring that your customizations and data persist across container restarts.

- MariaDB: A MariaDB database service, which serves as the backend database for the Drupal installation. It is configured with environment variables for secure access and data persistence through a dedicated volume.

- Portainer: A set of services (Portainer CE and Portainer Agent) that provide a user-friendly web UI for managing Docker environments. It's configured to ensure secure access and data persistence, facilitating easy management of your Docker containers, volumes, and networks.

- Traefik: A modern HTTP reverse proxy and load balancer that makes deploying microservices easy. Traefik is used here to manage SSL certificates automatically via Let's Encrypt, route external requests to the appropriate services, and enforce HTTPS redirection. It's configured with HTTP basic authentication for secure access to the dashboard and API.

# Getting Started

Install docker.
Copy `.example-env` to `.env` and set the variables.
(Use `echo $(htpasswd -nb TRAEFIK_USERNAME TRAEFIK_PASSWORD) | sed -e s/\\$/\\$\\$/g` to generate hashed traefik user password.)
Init docker swarm with `docker swarm init`.
Add [GitHub packages registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
May need to add constraints to node with `docker node update --label-add reverse-proxy.reverse-proxy-certificates=true <node-id>`. (Get your `<node-id>` with `docker node inspect self`)
Start SCS Manager ceployment environment with `./start.sh`.

# License

This project is licensed under the GPL v3 License - see the LICENSE file for details.