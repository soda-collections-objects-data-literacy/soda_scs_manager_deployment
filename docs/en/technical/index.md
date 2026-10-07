# Technical documentation

How the SODa SCS Manager deployment is built, installed, and operated. For end-user how-tos see the [User guide](../user/index.md).

## Start here

1. [Glossary](glossary.md) — terms used in this project (SCS, Keycloak, Traefik, naming, …).
2. [Prerequisites](initial-setup/prerequisites.md) — Docker, GitHub auth, `.env`.
3. [Pre-start steps](initial-setup/pre-start-steps.md) — `start.sh`, network, database, pre-install scripts.
4. [Post-configuration checklist](post-configuration/checklist.md) — Keycloak, Manager, Nextcloud, JupyterHub.

## Sections

- **[Service infrastructure](service-infrastructure/index.md)** — stack layout, Traefik, shared DB, Manager, Drive, Code, OpenGDB, website.
  - [Architecture overview (C4 / Mermaid)](service-infrastructure/architecture-overview.md)
  - [Naming vocabulary](service-infrastructure/naming-vocabulary.md) — `{scope}--{service}--{function}`
  - [Naming migration plan](service-infrastructure/naming-migration-plan.md)
  - [SCS Manager user lifecycle](service-infrastructure/scs-manager-user-lifecycle.md)
- **[Initial setup](initial-setup/index.md)** — before the first `docker compose up`
- **[Post-start](post-start/index.md)** — health checks after compose up
- **[Post-configuration](post-configuration/index.md)** — one-time service configuration
- **[Maintenance](maintenance/index.md)** — updates and backups ([update guide](maintenance/updates.md))
- **[Troubleshooting](troubleshooting/index.md)** — common failures and test scripts

## Reference

- [Reverse proxy backend config](knowledge-base/reverse-proxy-backend-config-knowledge-base.md)
- [Traefik labels and commands](knowledge-base/traefik-labels-and-commands.md)
- [Dedicated WissKI deployment (Uni Graz)](infrastruktur-uebersicht.md)

## Quick start

1. Clone the repository and initialize submodules.
2. Copy `example-env` to `.env` and set required variables ([Prerequisites](initial-setup/prerequisites.md)).
3. Run `./start.sh`.
4. Run `docker compose up -d`.
5. Follow the [post-configuration checklist](post-configuration/checklist.md).
