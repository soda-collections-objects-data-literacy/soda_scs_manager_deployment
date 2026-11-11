# Infrastructure inventory

Catalogue of every Compose environment, container, and host unit in the SODa SCS Manager deployment: **what exists**, **what it does**, and **where it is configured**.

For narrative wiring see [Service infrastructure](index.md). For C4 diagrams see [Architecture overview](architecture-overview.md). Naming: [Naming vocabulary](naming-vocabulary.md). Scripts: [Scripts catalogue](scripts.md). Site overlays: [Custom configs](custom-configs.md). Terms: [Glossary](../glossary.md).

## How Compose is wired

All stacks run as **one** Compose project. The root `.env` sets `COMPOSE_FILE` to a colon-separated list of base files and overrides. Run `docker compose` from the repo root (`SCS_ROOT_PATH`); do not pass `-f` unless you are debugging a single stack.

| Source of truth | Role |
|-----------------|------|
| `example-env` / `.env` | Domains, secrets, `COMPOSE_FILE`, `SCS_ROOT_PATH`, `SCS_*` container DNS |
| `docker-compose.yml` | Shared core: Traefik, MariaDB, Portainer, docs, rclone sidecar, DBMS |
| `<stack>/docker-compose.yml` | Submodule base definition |
| `00_custom_configs/<stack>/docker/docker-compose.override.yml` | Site-specific override (Traefik, volumes, names) |
| `start.sh` / `update-stack.bash` | Copy overrides into stack dirs when needed; run pre-install |

Dev vs Prime: on **dev**, `COMPOSE_FILE` may include `docker-compose.development.yml` (bind-mounted module/theme). On **Prime**, module and theme come from the production image — see [Dev to Prime](../maintenance/dev-to-prime.md).

Optional stacks (e.g. project website) appear in `example-env` but may be omitted from a host’s live `COMPOSE_FILE`.

---

## Core (`docker-compose.yml`)

| Container | Alias (soak) | Effect | Configured in |
|-----------|--------------|--------|---------------|
| `core--traefik--edge` | `scs--reverse-proxy` | HTTPS edge, ACME, middlewares, host routing | Root compose + Docker labels on each service |
| `core--mariadb--db` | `scs--database` | Shared MariaDB for Keycloak, Manager, Nextcloud, website | Root compose; DBs/users from pre-install scripts |
| `core--portainer--app` | `scs--portainer` | Container UI; WissKI stacks from SCS Manager | Root compose |
| `core--rclone--sidecar` | `nextcloud-mounter` | rclone `rcd` FUSE mounter for Nextcloud Drives / Team Folders | Root compose; [Nextcloud mount sidecar](nextcloud-mount-sidecar.md) |
| `core--docs--app` | — | Serves built Zensical docs from `./site` | `00_custom_configs/docs/nginx.conf` |
| `core--docsauth--proxy` | — | oauth2-proxy; gates `/en\|de/technical` behind admin SSO | Root compose + Keycloak client |
| `core--echo--app` | `scs--echo` | whoami debug endpoint | Root compose |
| `core--wisski-alias--edge` | — | Traefik label carrier: unprefixed WissKI host → legacy host | Root compose |
| `dbms--phpmyadmin--app` | `scs--phpmyadmin` | phpMyAdmin UI | `00_custom_configs/phpmyadmin/` |
| `dbms--forwardauth--proxy` | `scs--forward-auth` | Keycloak forward-auth for DBMS SSO | Root compose |

Shared Docker network: `reverse-proxy` (logical `core--traefik--net`). Sidecar ↔ Manager network: `nextcloud-mounter-net` / `core--rclone--net`.

---

## Application stacks

### Keycloak (`keycloak` + override)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `keycloak--keycloak--app` | Central IdP (OIDC) for Manager, Drive, Code, WebProtégé, DBMS, docs | `00_custom_configs/keycloak/docker/…`; realm from `templates/realm/scs-realm.json.tpl` via keycloak pre-install |

### SCS Manager (`scs-manager-stack`)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `manager--drupal--app` | Drupal SCS Manager UI and APIs | Stack override (+ `docker-compose.development.yml` on dev); `00_custom_configs/scs-manager-stack/drupal/`, OpenID tpl |
| `manager--redis--cache` | Object cache / sessions for Manager | Stack override |
| `scs-manager--database` / `scs-manager--varnish` | Present in base compose; **disabled** (`replicas: 0`) — uses shared MariaDB | Override |

### Nextcloud / Drive (`scs-nextcloud-stack`)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `nextcloud--nextcloud--app` | Nextcloud FPM | Override; post-install hooks under `scs-nextcloud-stack/hooks/` |
| `nextcloud--nginx--edge` | HTTP edge for Nextcloud | Stack nginx configs + override |
| `nextcloud--ods--app` | OnlyOffice Document Server | Override |
| `nextcloud--ods--edge` | OnlyOffice edge nginx | Override |
| `nextcloud--redis--cache` | Nextcloud Redis | Override |

### JupyterHub / Code (`jupyterhub`)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `jupyterhub--jupyterhub--app` | Hub; spawns user notebooks; binds project Team Folders | `00_custom_configs/jupyterhub/docker/…`; `jupyterhub_config.py` |
| `jupyterhub--spawner--builder` | Builds the notebook/spawner image (build only) | Same override |

### OpenGDB (`open_gdb`)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `opengdb--rdf4j--db` | Eclipse RDF4J triplestore (LMDB / optional ChangeLog Sail) | OpenGDB override + image |
| `opengdb--authproxy--proxy` | Authenticated SPARQL/API for WissKI and Manager; optional Keycloak SSO via `OPEN_GDB_KEYCLOAK_*` | Override (Django authproxy) |
| `opengdb--outproxy--proxy` | Outbound HTTP proxy for RDF4J | Override |
| `opengdb--nginx--edge` | Public edge for OpenGDB | `open_gdb/nginx/` + override |

### WebProtégé (`webprotege`)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `webprotege--webprotege--app` | Shared ontology editor (`webprotege:scs`) | Override + `00_custom_configs/webprotege/patches/` |
| `webprotege--mongodb--db` | MongoDB for WebProtégé | Override |

### SCS Health (`scs-health`)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `health--health--app` | Operator health dashboard (HTTPS + optional Docker status) | `00_custom_configs/scs-health/`; [SCS Health](scs-health.md) |

### Voyager (`scs-voyager` via custom override)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `voyager--voyager--app` | Static Smithsonian Voyager 3D viewer | `00_custom_configs/voyager/`; [Voyager](voyager.md) |

### Project website (optional)

| Container | Effect | Configured in |
|-----------|--------|---------------|
| `scs-project-website--drupal` / `--database` / `--redis` / `--varnish` | Public project website stack | `scs-project-website-stack/` + `00_custom_configs/scs-project-website-stack/` — only if listed in `COMPOSE_FILE` |

---

## WissKI instances (outside root `COMPOSE_FILE`)

Each catalogue is a **Portainer stack** from `wisski-base-stack`, created by SCS Manager — not merged into the root Compose project.

| Typical containers | Effect | Configured in |
|--------------------|--------|---------------|
| `{SERVICE_NAME}--varnish` | Full-page cache edge | Portainer stack env + Traefik labels |
| `{SERVICE_NAME}--drupal` | WissKI Drupal (nginx + PHP-FPM) | wisski-base-image entrypoint; [configs/](configs/index.md) |
| `{SERVICE_NAME}--redis` | Instance Redis | Stack compose |

Detail: [WissKI stack](wisski-stack/index.md). Private files, trusted hosts, Redis, reverse proxy: [Drupal settings snippets](configs/index.md).

---

## Host systemd units

Unit files live in `01_scripts/global/` and are installed into `/etc/systemd/system/` once per host.

| Unit | Effect |
|------|--------|
| `scs-nextcloud-mounts.service` | rshared self-bind of `NEXTCLOUD_MOUNTS_ROOT` before Docker |
| `scs-nextcloud-mount-reconcile.timer` | Every minute: re-create user/project FUSE mounts after sidecar restarts |
| `scs-demo-queue.timer` | Run demo project queue jobs outside the web request |
| `scs-wisski-update-queue.timer` | Run queued WissKI updates outside the web request |

See [Scripts catalogue](scripts.md#systemd-units) and [Pre-start steps](../initial-setup/pre-start-steps.md).

---

## Quick map: product name → stack

| Product language | Compose scope | Entry container |
|------------------|---------------|-----------------|
| Auth | `keycloak` | `keycloak--keycloak--app` |
| Manager | `manager` | `manager--drupal--app` |
| Drive | `nextcloud` | `nextcloud--nginx--edge` |
| Code | `jupyterhub` | `jupyterhub--jupyterhub--app` |
| Triplestore | `opengdb` | `opengdb--nginx--edge` |
| Ontologies | `webprotege` | `webprotege--webprotege--app` |
| Health | `health` | `health--health--app` |
| 3D viewer | `voyager` | `voyager--voyager--app` |
| Docs | `core` | `core--docs--app` |
| Catalogue (WissKI) | Portainer / `wisski--{id}` | `{SERVICE_NAME}--varnish` |
