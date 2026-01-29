# SODa SCS Manager Deployment — Documentation

This documentation describes how to deploy and operate the SODa SCS Manager deployment: a Docker Compose environment that runs a Drupal-based SCS Manager together with Keycloak, Nextcloud, JupyterHub, OpenGDB, and related services.

## Documentation overview

- **[Glossary](glossary.md)** — Definitions of terms used in this project (SCS, Keycloak, Traefik, OpenID Connect, etc.).

- **[Service infrastructure](service-infrastructure/index.md)** — What is in the stack and how services are wired: main compose, Traefik, shared database, Keycloak, SCS Manager, Nextcloud, JupyterHub, OpenGDB, and project website.

- **[Initial setup](initial-setup/index.md)** — What to do before the first `docker compose up`:
  - [Prerequisites](initial-setup/prerequisites.md) — Docker, GitHub authentication, and `.env` configuration.
  - [Pre-start steps](initial-setup/pre-start-steps.md) — Running `start.sh`: network, override copies, database start, and pre-install scripts.

- **[Post-start](post-start/index.md)** — What runs after `docker compose up -d` and how to verify that services are healthy.

- **[Post-configuration](post-configuration/index.md)** — One-time or periodic configuration inside each service after the stack is running, with a [checklist](post-configuration/checklist.md) for Keycloak, SCS Manager, Nextcloud, JupyterHub, and others.

## Reference

- [Proxy headers configuration](proxy-headers-configuration.md)
- [Reverse proxy backend config knowledge base](reverse-proxy-backend-config-knowledge-base.md)
- [Traefik labels and commands](traefik-labels-and-commands.md)

## Quick start

1. Clone the repository and initialize submodules.
2. Copy `example-env` to `.env` and set all required variables (see [Prerequisites](initial-setup/prerequisites.md)).
3. Run `./start.sh` to create the network, start the database, and run pre-install scripts.
4. Run `docker compose up -d` to start all services.
5. Follow the [post-configuration checklist](post-configuration/checklist.md) to configure Keycloak, SCS Manager, Nextcloud, JupyterHub, and related services.

For more detail, follow the links above.

## Viewing the docs (MkDocs in Docker)

From the **repository root** (where `mkdocs.yml` and `docs/` live), run:

```bash
docker run --rm -it -p 3456:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material
```

Then open [http://localhost:3456](http://localhost:3456). The container mounts the repo into `/docs` and runs `mkdocs serve` (default internal port 8000). Stop with `Ctrl+C`.

To only build the static site (no server):

```bash
docker run --rm -v "${PWD}:/docs" squidfunk/mkdocs-material build
```

Output is in `site/`.
