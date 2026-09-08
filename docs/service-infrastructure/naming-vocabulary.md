# Service naming vocabulary

Canonical vocabulary for Docker Compose **service keys**, **`container_name`**, and Docker DNS in this deployment.

**Pattern (always three segments, never shortened):**

```text
{scope}--{service}--{function}
```

Example: `nextcloud--redis--cache`, `nextcloud--nextcloud--app`, `nextcloud--ods--edge`, `core--mariadb--db`.

Compose service key = `container_name` = DNS name. Image/tag stays in the Compose file only.

Migration (Ist→Soll, aliases, Manager settings): [Naming migration plan](naming-migration-plan.md).  
Architecture context: [Architecture overview](architecture-overview.md).

---

## Levels

| Term | Meaning | Examples |
|------|---------|----------|
| **Scope** | Compose environment / stack ownership (who owns lifecycle) | `core`, `nextcloud`, `manager`, `keycloak`, `jupyterhub`, `opengdb`, `webprotege`, `website`, `health`, `dbms`; per-instance WissKI TBD (`wisski` / `proj-{id}` — see Wave Z) |
| **Service** | Concrete software component inside that scope | `traefik`, `mariadb`, `rclone`, `nextcloud`, `ods`, `nginx`, `redis`, `drupal`, `keycloak`, `portainer`, `authproxy` |
| **Function** | Role of that component *in this* scope | See [Functions](#functions) below |

**Scope** here is *not* an OAuth2/OIDC scope — see [Glossary: scope (OAuth2/OIDC)](../glossary.md#scope-oauth2oidc) vs [scope (naming)](../glossary.md#scope-naming).

Capability labels used in product language (`drive`, `code`, …) are **not** DNS scopes; DNS uses the Compose environment name (`nextcloud`, `jupyterhub`, …).

---

## Functions

Fixed, short vocabulary. Prefer these tokens; do not invent synonyms (`frontend` instead of `edge`, etc.) without updating this page.

| Function | Meaning | Typical software |
|----------|---------|------------------|
| **app** | Primary application process | Nextcloud FPM, Drupal, Keycloak, OnlyOffice Document Server, Portainer, Health UI |
| **edge** | HTTP entry in front of an app (TLS termination may be elsewhere) | Traefik, Varnish, nginx reverse proxy |
| **db** | Persistent datastore | MariaDB, MongoDB, RDF4J |
| **cache** | Cache / sessions | Redis |
| **proxy** | Auth or protocol proxy *behind* the platform edge | forward-auth, OpenGDB authproxy/outproxy |
| **sidecar** | Helper process for other services | rclone FUSE mounter |
| **builder** | Image build or oneshot job | JupyterHub image builder |

---

## Scopes (Compose environments)

| Scope | Owns |
|-------|------|
| `core` | Shared platform infra: Traefik, MariaDB, rclone sidecar, Portainer, echo, … |
| `nextcloud` | Drive stack (Nextcloud, OnlyOffice, their nginx edges, Redis) |
| `manager` | SCS Manager (Drupal, Redis, optional Varnish) |
| `keycloak` | Identity provider |
| `jupyterhub` | Hub + spawner image builder (not user notebooks) |
| `opengdb` | Triplestore stack (RDF4J, authproxy, outproxy, nginx) |
| `webprotege` | Ontology editor + MongoDB |
| `website` | Project website stack (if enabled) |
| `health` | Operator health dashboard |
| `dbms` | phpMyAdmin + forward-auth |
| `proj-{id}` / `wisski--{id}` | Per-project WissKI instance (Portainer). **Deferred** — Today remains `{SERVICE_NAME}--drupal` etc. Prefer leaning `wisski--{id}--*` over `proj-{id}`; see [Naming migration plan — Wave Z](naming-migration-plan.md#wave-z--wisski-instances--todo--deferred). |

---

## Service tokens (selected)

Short, stable tokens used in the middle segment. Prefer these over long product strings in DNS.

| Token | Software |
|-------|----------|
| `traefik` | Traefik |
| `mariadb` | MariaDB |
| `rclone` | rclone (FUSE mounter) |
| `portainer` | Portainer CE |
| `echo` | Whoami / echo debug |
| `nextcloud` | Nextcloud |
| `ods` | OnlyOffice Document Server |
| `nginx` | nginx (as edge for Nextcloud app) |
| `redis` | Redis |
| `drupal` | Drupal |
| `varnish` | Varnish |
| `keycloak` | Keycloak |
| `jupyterhub` | JupyterHub |
| `spawner` | Jupyter spawner image build |
| `rdf4j` | Eclipse RDF4J |
| `authproxy` | OpenGDB AuthProxy |
| `outproxy` | OpenGDB OutProxy |
| `webprotege` | WebProtégé |
| `mongodb` | MongoDB |
| `phpmyadmin` | phpMyAdmin |
| `forwardauth` | traefik-forward-auth |
| `health` | SCS Health app |

---

## Environment variables for container DNS

Ops scripts and Manager defaults read these (defaults = current names). Canonical list also in `example-env` and `01_scripts/global/scs-container-names.bash`.

| Variable | Default (today) | Used for |
|----------|-----------------|----------|
| `SCS_CONTAINER_DATABASE` | `core--mariadb--db` (alias `scs--database`) | `docker exec` / compose service; JDBC `*_DB_HOST` / Manager `dbHost` may still use the alias until cutover |
| `SCS_CONTAINER_REVERSE_PROXY` | `core--traefik--edge` (alias `scs--reverse-proxy`) | Scripts / Manager env; Docker **network** stays `reverse-proxy` |
| `SCS_CONTAINER_NEXTCLOUD_MOUNTER` | `nextcloud-mounter` | Builds `NEXTCLOUD_MOUNTER_RC_URL` if unset |
| `SCS_CONTAINER_AUTHPROXY` | `opengdb--authproxy--proxy` (alias `scs--authproxy`) | OpenGDB nginx; `INTERNAL_TS_BASE` still uses the alias until WissKI cutover |
| `SCS_CONTAINER_RDF4J` | `opengdb--rdf4j--db` (alias `scs--rdf4j`) | OpenGDB `RDF4J_HOSTNAME` |
| `SCS_CONTAINER_OUTPROXY` | `opengdb--outproxy--proxy` (alias `scs--outproxy`) | RDF4J JVM proxy host |
| `SCS_CONTAINER_OPENGDB_PROXY` | `opengdb--nginx--edge` (alias `scs--opengdb-proxy`) | Scripts / compose service |
| `SCS_CONTAINER_PORTAINER` | `core--portainer--app` (alias `scs--portainer`) | Scripts; Manager Portainer URL is usually public HTTPS |
| `SCS_CONTAINER_PHPMYADMIN` | `dbms--phpmyadmin--app` (alias `scs--phpmyadmin`) | `docker exec` / compose service |
| `SCS_CONTAINER_FORWARD_AUTH` | `dbms--forwardauth--proxy` (alias `scs--forward-auth`) | Traefik `dbms-sso` still uses the alias DNS until cutover |
| `SCS_CONTAINER_KEYCLOAK` | `keycloak--keycloak--app` (alias `keycloak--keycloak`) | `docker exec` / compose service; public Host stays `KC_DOMAIN` |
| `SCS_CONTAINER_MANAGER` | `manager--drupal--app` (alias `scs-manager--drupal`) | `scs-drush` / `docker exec`; Traefik router IDs lag |
| `SCS_CONTAINER_MANAGER_REDIS` | `manager--redis--cache` (aliases `scs-manager--redis`, `redis`) | Manager Redis |
| `NEXTCLOUD_MOUNTER_RC_URL` | `http://$SCS_CONTAINER_NEXTCLOUD_MOUNTER:5572` | Manager sidecar client |
| `INTERNAL_TS_BASE` | `http://scs--authproxy:8000` (alias, soak) | WissKI tuning / Manager default; flip after Wave F2 |

**Resolution order in Manager PHP:** explicit `soda_scs_manager.settings` value → env → hardcoded default (same as today’s DNS).

**Compose `depends_on`:** still uses literal service keys until the rename wave changes the service key; connection strings already use `${SCS_CONTAINER_*}` so flipping `.env` after aliases exist is enough for DB/JDBC/mounter URLs.

Flip `.env` (and live Manager settings) only after the Compose service exists under the new name **or** an alias still serves the old name.

1. Exactly **two** `--` separators → three segments: `scope--service--function`.
2. **Always explicit:** even when service name equals scope, keep both — `nextcloud--nextcloud--app`, not `nextcloud--app`.
3. Function is never folded into the service token: use `nextcloud--ods--edge`, not `nextcloud--nginx-edge-ods` or `nextcloud--nginx--edge-ods`.
4. Uniqueness = Scope × Service × Function across the whole deployment (`manager--redis--cache` ≠ `nextcloud--redis--cache`).
5. Do not put image tags or versions in the name.

---

## Worked examples

### Nextcloud Compose environment

| Role | Name |
|------|------|
| Nextcloud FPM | `nextcloud--nextcloud--app` |
| OnlyOffice Document Server | `nextcloud--ods--app` |
| nginx in front of Nextcloud | `nextcloud--nginx--edge` |
| nginx in front of OnlyOffice | `nextcloud--ods--edge` |
| Redis | `nextcloud--redis--cache` |

### WebProtégé

| Role | Name |
|------|------|
| WebProtégé app | `webprotege--webprotege--app` |
| MongoDB | `webprotege--mongodb--db` |

### Core (shared)

| Role | Name |
|------|------|
| Traefik | `core--traefik--edge` |
| MariaDB | `core--mariadb--db` |
| rclone FUSE sidecar | `core--rclone--sidecar` |
| Portainer | `core--portainer--app` |

### Not this scheme

| Name | Why |
|------|-----|
| `jupyter-{username}` | DockerSpawner notebook containers — leave as-is |
| Public Hosts (`drive.…`, `auth.…`) | Traefik / TLS / OIDC — not container DNS |
| `COMPOSE_FILE` paths (`scs-nextcloud-stack/…`) | Repo directories — separate from DNS naming |

---

## Related

- [Glossary](../glossary.md) — short definitions + OAuth “scope” disambiguation  
- [Naming migration plan](naming-migration-plan.md) — waves, aliases, Env, `soda_scs_manager.settings`, code hardcodes  
