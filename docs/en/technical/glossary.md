# Glossary

Terms used in the SODa SCS Manager deployment. For the full container catalogue see [Infrastructure inventory](service-infrastructure/inventory.md). Naming scheme detail: [Service naming vocabulary](service-infrastructure/naming-vocabulary.md).

---

## Service naming (`{scope}--{service}--{function}`)

Full vocabulary: **[Service naming vocabulary](service-infrastructure/naming-vocabulary.md)**. Migration: [Naming migration plan](service-infrastructure/naming-migration-plan.md).

### function (naming)

Role of a container *inside* its Compose scope: `app`, `edge`, `cache`, `db`, `proxy`, `sidecar`, or `builder`. Third segment of `{scope}--{service}--{function}`. See [Functions](service-infrastructure/naming-vocabulary.md#functions).

### scope (naming)

Compose environment / stack ownership for container DNS (e.g. `core`, `nextcloud`, `manager`). First segment of `{scope}--{service}--{function}`. Not the same as an [OAuth2/OIDC scope](#scope-oauth2oidc).

### service (naming)

Concrete software component token inside a scope (e.g. `redis`, `ods`, `traefik`, `mariadb`). Second segment of `{scope}--{service}--{function}`. Compose service key and `container_name` use the full three-part string, not this token alone.

### ods

Short service token for OnlyOffice Document Server in the `nextcloud` scope (`nextcloud--ods--app`, `nextcloud--ods--edge`).

### alias (soak)

Temporary Docker DNS name kept during the naming migration so old URLs and Manager settings keep working (e.g. `scs--database` → `core--mariadb--db`). See [Naming migration plan](service-infrastructure/naming-migration-plan.md).

---

## Platform and identity

### client (Keycloak)

In Keycloak, a *client* is an application that can request authentication (e.g. SCS Manager, Nextcloud, JupyterHub). Each client has a client ID, optional client secret, redirect URIs, and assigned client scopes. OAuth2/OIDC tokens are issued for a specific client.

### COMPOSE_FILE

Environment variable that lists the set of `docker-compose` files merged for a single `docker compose` run. In this project it ties together the main stack, submodule stacks, and overrides (see `example-env`). Directory paths in `COMPOSE_FILE` are **not** renamed when container DNS moves to `{scope}--{service}--{function}`.

### forward-auth

Traefik middleware pattern: before the request reaches the backend, Traefik asks an auth service (here `dbms--forwardauth--proxy`) whether the user is signed in. Used for phpMyAdmin SSO against Keycloak.

### gid

Group ID. In this deployment, Keycloak can expose numeric group IDs via a user attribute `gid` (multivalued). JupyterHub uses these in the spawner to map the user into the correct Linux groups inside the notebook container.

### IdP

Identity Provider. Keycloak acts as the IdP for SCS Manager, Nextcloud, JupyterHub, WebProtégé, and optionally OpenGDB AuthProxy in this deployment.

### Keycloak

Open-source identity and access management server. In this deployment it provides a single realm with OAuth2/OpenID Connect clients for SCS Manager, Nextcloud, JupyterHub, DBMS, WebProtégé, DIDMOS, and optionally OpenGDB. It uses the shared MariaDB database.

### OAuth2

Authorization framework used for delegated access. Keycloak implements OAuth2 and issues access and refresh tokens to clients.

### oauth2-proxy

Sidecar-style auth reverse proxy (`core--docsauth--proxy`) that protects documentation technical paths with Keycloak login.

### OpenID Connect (OIDC)

Identity layer on top of OAuth2. Clients use OIDC to obtain an ID token and userinfo (e.g. username, groups) in addition to access tokens. SCS Manager, Nextcloud, JupyterHub, WebProtégé, and optionally OpenGDB AuthProxy use OIDC with Keycloak.

### realm (Keycloak)

A realm is a Keycloak namespace for users, groups, roles, and clients. This deployment uses a single realm (e.g. `main`), defined by the template `00_custom_configs/keycloak/templates/realm/scs-realm.json.tpl`.

### reverse-proxy (network)

Docker network name used by the main stack and all submodule stacks. Traefik and every HTTP/TCP service attach to this network so Traefik can route by host and path. Under the naming scheme this is the shared edge network (logical `core--traefik--net`); the Docker network `name:` may stay `reverse-proxy` for a long time during migration.

### SCS

In this project, SCS refers to the SODa Collections/Services context: the SCS Manager (Drupal), SCS-related stacks (Nextcloud, JupyterHub, project website), and shared infrastructure (database, Keycloak, Traefik).

### scope (OAuth2/OIDC)

A scope requests a set of claims or permissions. Keycloak defines client scopes (e.g. `groups`, `email`, `profile`). Clients are assigned default and optional client scopes; the token and userinfo include the corresponding claims (e.g. group membership, gids). Distinct from [scope (naming)](#scope-naming).

### Traefik

Reverse proxy and load balancer used in this deployment. It handles HTTP/HTTPS, TLS (e.g. Let’s Encrypt), and routes requests to the correct service based on Docker labels (e.g. `Host(...)`). Target container name: `core--traefik--edge`.

### WissKI

Semantic content management system (Drupal-based). In this deployment, SCS Manager can integrate with WissKI; Keycloak defines a group `wisski_admin` for WissKI administrators, and SCS Manager uses a Portainer API token for WissKI stack management. Per-instance containers use scope `proj-{id}` / `wisski--{id}` under the naming scheme (Wave Z deferred).

---

## Compose roles and helpers

### builder

Compose **function**: a one-shot or build-only container (e.g. `jupyterhub--spawner--builder`) that produces an image rather than serving traffic.

### edge

Compose **function**: HTTP entry in front of an app (nginx, Varnish, Traefik). TLS may terminate here or further upstream.

### override (`docker-compose.override.yml`)

Site-specific Compose file that replaces or extends the submodule base (volumes, networks, Traefik labels, disabled local DB). Canonical copies live under `00_custom_configs/<stack>/docker/`. See [Custom configs](service-infrastructure/custom-configs.md).

### sidecar

A helper container that runs **beside** the main application to provide a capability the app should not hold itself. In this deployment the primary sidecar is `core--rclone--sidecar` (alias `nextcloud-mounter`): it alone has `SYS_ADMIN` + `/dev/fuse` and mounts Nextcloud via WebDAV/FUSE for Manager, Jupyter, and WissKI. See [Nextcloud mount sidecar](service-infrastructure/nextcloud-mount-sidecar.md).

### stack / Compose environment

A group of services owned by one submodule or the root compose file (Keycloak, Nextcloud, Manager, …). Wired together via `COMPOSE_FILE`. Product names (Drive, Code) map to Compose scopes — see [Infrastructure inventory](service-infrastructure/inventory.md).

---

## Files, mounts, and Drupal storage

### FUSE

Filesystem in Userspace. Used by rclone in the sidecar so a Nextcloud account appears as a normal directory tree on the host (`NEXTCLOUD_MOUNTS_ROOT`) and can be bind-mounted into Jupyter or WissKI.

### NEXTCLOUD_MOUNTS_ROOT

Host directory (default `/var/lib/scs/nextcloud-mounts`) that holds per-user Drive mounts and project Team Folder mounts. Must be an **rshared** self-bind (`scs-nextcloud-mounts.service`) so FUSE mounts propagate into containers.

### private files / `file_private_path` / `private://`

Drupal’s private file system: uploads that must **not** be served as static files by nginx. Configured with `$settings['file_private_path']`.

| Context | Typical path | Volume / mount |
|---------|--------------|----------------|
| WissKI instance | `/opt/drupal/private-files` | `{SERVICE_NAME}--drupal-private-files`; Nextcloud Team Folder bind → `private://nextcloud` |
| SCS Manager | `/var/scs-manager` | Volume `scs-manager--private-files`; snapshots under `private://snapshots/…` |

Docs: [Private files](service-infrastructure/configs/private-files.md). Module **PFDP** (Private Files Download Permission) can block `private://` downloads unless a bypass rule exists (Manager snapshots need `/snapshots` bypass).

### public files / `public://`

Drupal stream wrapper for files under the web-accessible files directory (`sites/default/files`). Opposite of private files.

### rshared / rslave

Linux mount **propagation** flags. The host mounts root is `rshared` so FUSE mounts appear for consumers; Jupyter/WissKI bind the project folder with `rslave` so they see the tree without re-exporting mounts outward.

### Team Folder

Nextcloud **Groupfolders** project directory owned by a service account. The sidecar mounts it under `_projects/…`; Jupyter and WissKI bind only that project path, not the whole user Drive.

---

## Triplestore and RDF (OpenGDB / RDF4J)

### AuthProxy

Django service (`opengdb--authproxy--proxy`) in front of RDF4J: authenticates SPARQL/API access for WissKI and SCS Manager (alias `scs--authproxy` during soak). Optional Keycloak OIDC SSO via `OPEN_GDB_KEYCLOAK_*` (see [Post-configuration checklist → OpenGDB](post-configuration/checklist.md#opengdb)).

### ChangeLog Sail / `opengdb:ChangeLogSail`

Custom RDF4J **Sail** stacked over a store that records write transactions into a hidden log graph (revisions for sync/audit). Opt-in via `RDF4J_CHANGELOG=1` or `enable_changelog`. Documented in `open_gdb/docs/change-log.md`.

### LMDB / LmdbStore

Lightning Memory-Mapped Database backend for RDF4J repositories (default for new OpenGDB repos). Migration from NativeStore: `01_scripts/open_gdb/migrate-repositories-to-lmdb.py`.

### NativeStore

Older on-disk RDF4J store (`openrdf:NativeStore`) using B-tree index files (`values.dat`, …). Still seen on long-lived repos; new repos prefer LMDB.

### OutProxy

Outbound HTTP proxy container (`opengdb--outproxy--proxy`) used by RDF4J for external fetches.

### RDF4J

Eclipse RDF4J: Java RDF framework and server used as the shared triplestore (`opengdb--rdf4j--db`). Exposes SPARQL and REST repository APIs.

### Sail / SailRepository

RDF4J’s storage abstraction (“Storage And Inference Layer”). A **SailRepository** wraps one or more stacked Sails (e.g. LMDB store, optional ChangeLog Sail). People sometimes say “RDF Sail” for this layer. Not related to Compose `sidecar`.

### SPARQL

Query (and update) language for RDF graphs. WissKI talks to OpenGDB/AuthProxy with SPARQL over HTTP.

### Triplestore

Database specialised for RDF triples/quads. In this deployment: RDF4J behind OpenGDB AuthProxy/nginx.

---

## Ops and hosts

### dev / Prime

Two hosts share this repo layout. **dev** (`SCS_SUBDOMAIN=dev-scs`) bind-mounts module/theme git checkouts. **Prime** (`scs`, host `scs-prime`) runs module/theme from the production image. Shipping: [Dev to Prime](maintenance/dev-to-prime.md).

### Portainer

Container management UI (`core--portainer--app`). SCS Manager uses its API to create/update/delete WissKI stacks.

### pre-install

Scripts under `01_scripts/**/pre-install.sh` run by `start.sh` after MariaDB is up: create DBs/users, render templates (realm, OIDC YAML), prepare host paths.

### reconcile (Nextcloud mounts)

Re-create FUSE mounts after the sidecar restarts or projects change. Done by Drush (`scs:nextcloud-reconcile`, `scs:nextcloud-project-reconcile`) on a systemd timer because Drupal cron alone is too slow.

### SCS_ROOT_PATH

Absolute path to the deployment checkout on the host. Used in override volume mounts so Compose resolves paths correctly when run from the repo root.

### Zensical

Static documentation generator (Material-for-MkDocs successor) used for `docs/`. Build: `01_scripts/global/build-docs.bash` → `./site` → `core--docs--app`.
