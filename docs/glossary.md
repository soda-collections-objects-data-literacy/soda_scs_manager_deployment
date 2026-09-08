# Glossary

Terms used in the SODa SCS Manager deployment documentation.

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

---

## Platform and identity

**client** (Keycloak)
In Keycloak, a *client* is an application that can request authentication (e.g. SCS Manager, Nextcloud, JupyterHub). Each client has a client ID, optional client secret, redirect URIs, and assigned client scopes. OAuth2/OIDC tokens are issued for a specific client.

**COMPOSE_FILE**
Environment variable that lists the set of `docker-compose` files merged for a single `docker compose` run. In this project it ties together the main stack, submodule stacks, and overrides (see `example-env`). Directory paths in `COMPOSE_FILE` are **not** renamed when container DNS moves to `{scope}--{service}--{function}`.

**gid**
Group ID. In this deployment, Keycloak can expose numeric group IDs via a user attribute `gid` (multivalued). JupyterHub uses these in the spawner to map the user into the correct Linux groups inside the notebook container.

**IdP**
Identity Provider. Keycloak acts as the IdP for SCS Manager, Nextcloud, and JupyterHub in this deployment.

**Keycloak**
Open-source identity and access management server. In this deployment it provides a single realm with OAuth2/OpenID Connect clients for SCS Manager, Nextcloud, JupyterHub, and DIDMOS. It uses the shared MariaDB database.

**OAuth2**
Authorization framework used for delegated access. Keycloak implements OAuth2 and issues access and refresh tokens to clients.

**OpenID Connect (OIDC)**
Identity layer on top of OAuth2. Clients use OIDC to obtain an ID token and userinfo (e.g. username, groups) in addition to access tokens. SCS Manager, Nextcloud, and JupyterHub use OIDC with Keycloak.

**realm** (Keycloak)
A realm is a Keycloak namespace for users, groups, roles, and clients. This deployment uses a single realm (e.g. `main`), defined by the template `00_custom_configs/keycloak/templates/realm/scs-realm.json.tpl`.

**reverse-proxy (network)**
Docker network name used by the main stack and all submodule stacks. Traefik and every HTTP/TCP service attach to this network so Traefik can route by host and path. Under the naming scheme this is the shared edge network (logical `core--traefik--net`); the Docker network `name:` may stay `reverse-proxy` for a long time during migration.

**SCS**
In this project, SCS refers to the SODa Collections/Services context: the SCS Manager (Drupal), SCS-related stacks (Nextcloud, JupyterHub, project website), and shared infrastructure (database, Keycloak, Traefik).

### scope (OAuth2/OIDC)

A scope requests a set of claims or permissions. Keycloak defines client scopes (e.g. `groups`, `email`, `profile`). Clients are assigned default and optional client scopes; the token and userinfo include the corresponding claims (e.g. group membership, gids). Distinct from [scope (naming)](#scope-naming).

**Traefik**
Reverse proxy and load balancer used in this deployment. It handles HTTP/HTTPS, TLS (e.g. Let’s Encrypt), and routes requests to the correct service based on Docker labels (e.g. `Host(...)`). Target container name: `core--traefik--edge`.

**WissKI**
Semantic content management system (Drupal-based). In this deployment, SCS Manager can integrate with WissKI; Keycloak defines a group `wisski_admin` for WissKI administrators, and SCS Manager uses a Portainer API token for WissKI stack management. Per-instance containers use scope `proj-{id}` under the naming scheme.
