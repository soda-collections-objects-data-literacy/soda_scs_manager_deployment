# Custom configs catalogue

Site-specific overlays live in `00_custom_configs/`. They are **not** submodule content: they adapt each stack to this deployment (Traefik hosts, shared MariaDB, SSO, Drupal snippets, patches).

Related: [Infrastructure inventory](inventory.md), [Scripts catalogue](scripts.md), [Architecture — where configs live](architecture-overview.md#5-where-configs-live).

## Pattern

| Kind | Typical path | How it reaches the container |
|------|--------------|------------------------------|
| Compose override | `00_custom_configs/<stack>/docker/docker-compose.override.yml` | Listed in `COMPOSE_FILE`, or copied into `<stack>/` by `start.sh` / `update-stack` |
| Templates | `*.tpl` | `envsubst` / pre-install → generated file under the stack dir |
| Drupal PHP snippets | `scs-manager-stack/drupal/*.settings.php` | `require` from Drupal `settings.php` / mounted `custom_configs` |
| nginx / app configs | `docs/nginx.conf`, Voyager template, phpMyAdmin PHP | Volume mounts in compose |
| Patches | `webprotege/patches/` | Applied in the WebProtégé build tree |

Overrides use `${SCS_ROOT_PATH}/…` for host binds and often `volumes: !override` / `networks: !override` / `ports: !reset []` so paths resolve from the repo root and Traefik owns HTTP.

---

## Per directory

### `docs/`

| File | Effect |
|------|--------|
| `nginx.conf` | nginx for `core--docs--app` serving `./site` |

### `jupyterhub/docker/`

| File | Effect |
|------|--------|
| `docker-compose.override.yml` | Container names, Traefik, Nextcloud mounts bind, networks/aliases |

### `keycloak/`

| File | Effect |
|------|--------|
| `docker/docker-compose.override.yml` | Traefik, shared MariaDB, `keycloak--keycloak--app` |
| `templates/realm/scs-realm.json.tpl` | Realm, clients, groups → `keycloak/import/${KC_REALM}.json` (pre-install) |

### `open_gdb/docker/`

| File | Effect |
|------|--------|
| `docker-compose.override.yml` | `opengdb--*` names, legacy aliases (`scs--rdf4j`, `scs--authproxy`, …), networks |

### `phpmyadmin/`

| File | Effect |
|------|--------|
| `docker/docker-compose.override.yml` | Mounts signon configs into `dbms--phpmyadmin--app` |
| `configs/config.user.inc.php`, `signon.php`, `signon-script.php` | Keycloak forward-auth sign-on for phpMyAdmin |

### `scs-health/docker/`

| File | Effect |
|------|--------|
| `docker-compose.override.yml` | Traefik host, build args, alias `scs--health` |

### `scs-manager-stack/`

| File | Effect |
|------|--------|
| `docker/docker-compose.override.yml` | Canonical Manager override (Traefik, shared DB, Redis, mounts, snapshots). On Prime, copied to `scs-manager-stack/docker-compose.override.yml` |
| `docker/docker-compose.development.yml` | Dev-only bind mounts for custom module/theme/sites |
| `drupal/reverse-proxy.settings.php` | Drupal reverse proxy / trusted headers |
| `drupal/file-private-path.settings.php` | `$settings['file_private_path'] = '/var/scs-manager'` for snapshots |
| `drupal/openid-connect.settings.php` (+ `.tpl`) | OpenID Connect UX / behaviour |
| `drupal/logging.settings.php` | Drupal logging overrides |
| `openid/openid_connect.client.scs_sso.yml.tpl` | → `scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml` (pre-install) |

See also [Private files](configs/private-files.md) for WissKI vs Manager private paths.

### `scs-nextcloud-stack/docker/`

| File | Effect |
|------|--------|
| `docker-compose.override.yml` | Names, hooks, skeleton, integration app mounts, Traefik aliases, ODS timeouts |

### `scs-project-website-stack/docker/`

| File | Effect |
|------|--------|
| `docker-compose.override.yml` | Site volumes/networks — only if the website stack is in `COMPOSE_FILE` |

### `voyager/`

| File | Effect |
|------|--------|
| `docker/docker-compose.override.yml` + `Dockerfile` | Static nginx image from `scs-voyager/` sources |
| `nginx/default.conf.template` | Voyager nginx vhost template |

### `webprotege/`

| File | Effect |
|------|--------|
| `docker/docker-compose.override.yml` | Traefik/networks; image `webprotege:scs`; Mongo aliases |
| `patches/` | Deltas vs upstream (OIDC SSO, project REST API, Docker build) — see `patches/README.md` |

### `default-page/`

| File | Effect |
|------|--------|
| `index.html`, `nginx.conf` | Legacy static landing; bare-domain redirect is now Traefik labels on the core edge. Keep only if you still run a dedicated default-page service. |

---

## Generated vs source

| Generated artefact | Produced by | Do not edit by hand |
|--------------------|-------------|---------------------|
| `keycloak/import/${KC_REALM}.json` | keycloak pre-install | Re-run pre-install / fix the `.tpl` |
| `scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml` | manager pre-install | Fix the `.tpl` |
| `./site/` | `build-docs.bash` | Edit `docs/` and rebuild |

Secrets and host-specific values stay in `.env` (from `example-env`), never in the templates committed without placeholders.
