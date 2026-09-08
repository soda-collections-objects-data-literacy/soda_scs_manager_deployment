# Service naming migration plan

Review document for a **piecewise, low-blast** rename toward:

```text
{scope}--{service}--{function}
```

**No renames in this change set** — only the plan. See also [Architecture overview](architecture-overview.md).

**Invariant:** Compose **service key** = **`container_name`** = Docker DNS name = target string. Never shorten (no `nextcloud--app`; always `nextcloud--nextcloud--app`).

Related risk: `soda_scs_manager.settings`, PHP defaults, `.env` host values, and scripts hardcode several Docker DNS names. Changing Compose without **aliases** or config cutover **will** break Manager, WissKI SPARQL, mounts, and pre-install scripts.

---

## 1. Goals and non-goals

| Do | Don't (yet) |
|----|-------------|
| Three-part names: scope (Compose env) · service (software) · function (role) | Big-bang rename of all stacks in one PR |
| Alias window so **old** DNS keeps resolving | Rename Traefik **public** hostnames / domains |
| Inventory every consumer before each wave | Rename WissKI instance containers first |
| Cut over Manager settings / Env **after** aliases work | Rename `COMPOSE_FILE` **directory paths** in the same waves |
| Verify with ripgrep + smoke tests | Rely on “we updated compose only” |
| Stay explicit (`nextcloud--nextcloud--app`) | Collapse when service ≡ scope |

**Out of scope for early waves:** public domains (`drive.*`, `auth.*`), OIDC client IDs based on URLs, Let's Encrypt cert names, Jupyter notebook prefix `jupyter-` (DockerSpawner), git/submodule folder names.

---

## 2. Naming model

Canonical definitions (scopes, service tokens, functions, delimiter rules): **[Service naming vocabulary](naming-vocabulary.md)**.

Summary: `{scope}--{service}--{function}` — Compose env · software · role. Always explicit (`nextcloud--nextcloud--app`). Compose service key = `container_name` = DNS.

Compose **service key** and **`container_name`** must equal the target. During each wave, keep the **Today** value as a Docker network alias until cutover.

---

## 3. Complete Ist → Soll

During each wave: introduce **Target** as service key + `container_name`, keep **Today** as network **alias** until Env, scripts, Manager settings, and code fallbacks no longer reference Today.

### 3.1 Containers / Compose services

| Wave | Scope | Today (DNS / `container_name`) | Target `{scope}--{service}--{function}` | Alias until cutover | Hot consumers (non-exhaustive) |
|------|-------|--------------------------------|------------------------------------------|---------------------|--------------------------------|
| A | `core` | `scs--echo` | `core--echo--app` | `scs--echo` | compose, docs |
| A | `health` | `scs--health` | `health--health--app` | `scs--health` | compose, Traefik labels, Health docs |
| B | `core` | `nextcloud-mounter` | `core--rclone--sidecar` | `nextcloud-mounter` | `NEXTCLOUD_MOUNTER_RC_URL`, Manager override `depends_on`, `NextcloudMounterClient.php` fallback |
| C | `core` | `scs--database` | `core--mariadb--db` | `scs--database` | `.env` `*_DB_HOST`, JDBC `KC_DB_URL`, `MYSQL_HOST`, `DB_HOST`, `start.sh`, all `pre-install`/`backup` `docker exec`, `soda_scs_manager.settings` `dbHost`, PHP fallbacks |
| D | `core` | `scs--reverse-proxy` | `core--traefik--edge` | `scs--reverse-proxy` | many `depends_on`, logs/runbooks; Traefik **router** label IDs may lag |
| E | `core` | `scs--portainer` | `core--portainer--app` | `scs--portainer` | Portainer volume; Manager Portainer host often **public** HTTPS — still verify internal DNS |
| E | `dbms` | `scs--phpmyadmin` | `dbms--phpmyadmin--app` | `scs--phpmyadmin` | phpMyAdmin override |
| E | `dbms` | `scs--forward-auth` | `dbms--forwardauth--proxy` | `scs--forward-auth` | pair with phpMyAdmin |
| F | `opengdb` | `scs--rdf4j` | `opengdb--rdf4j--db` | `scs--rdf4j` | Compose key today `rdf4j`; `RDF4J_HOSTNAME` |
| F | `opengdb` | `scs--authproxy` | `opengdb--authproxy--proxy` | `scs--authproxy` | Manager `triplestore.generalSettings.internalHost`, form default, WissKI `TS_*`, `apply-performance-tuning.bash`, `DJANGO_ALLOWED_HOSTS` |
| F | `opengdb` | `scs--outproxy` | `opengdb--outproxy--proxy` | `scs--outproxy` | JVM `-Dhttp.proxyHost=…` |
| F | `opengdb` | `scs--opengdb-proxy` | `opengdb--nginx--edge` | `scs--opengdb-proxy` | Compose key today `nginx` |
| G | `core` | `scs--access-proxy` | `core--accessproxy--proxy` **or remove** | `scs--access-proxy` | `accessProxy.generalSettings.containerName`; **not** in current root compose — confirm dead |
| H | `keycloak` | `keycloak--keycloak` | `keycloak--keycloak--app` | `keycloak--keycloak` | Compose key `keycloak`; DB already via `core--mariadb--db` |
| H | `manager` | `scs-manager--drupal` | `manager--drupal--app` | `scs-manager--drupal` | Traefik, `scs-drush` habits, overrides |
| H | `manager` | `scs-manager--redis` | `manager--redis--cache` | `scs-manager--redis` | |
| H | `manager` | `scs-manager--database` | *(no-op — stay disabled)* | — | Uses shared DB; do **not** revive |
| H | `manager` | `scs-manager--varnish` | `manager--varnish--edge` | `scs-manager--varnish` | Often disabled; rename only if re-enabled |
| H | `nextcloud` | `nextcloud--nextcloud` | `nextcloud--nextcloud--app` | `nextcloud--nextcloud` | OnlyOffice internal URLs, occ |
| H | `nextcloud` | `nextcloud--redis` | `nextcloud--redis--cache` | `nextcloud--redis` | `NEXTCLOUD_REDIS_HOST` |
| H | `nextcloud` | `nextcloud--nextcloud-reverse-proxy` | `nextcloud--nginx--edge` | `nextcloud--nextcloud-reverse-proxy` | Traefik → nginx → FPM |
| H | `nextcloud` | `nextcloud--onlyoffice-document-server` | `nextcloud--ods--app` | `nextcloud--onlyoffice-document-server` | Document Server |
| H | `nextcloud` | `nextcloud--onlyoffice-reverse-proxy` | `nextcloud--ods--edge` | `nextcloud--onlyoffice-reverse-proxy` | nginx in front of ODS; **service=`ods`**, **function=`edge`** |
| H | `jupyterhub` | `jupyterhub--jupyterhub` or `${JUPYTERHUB_SERVICE_NAME}` | `jupyterhub--jupyterhub--app` | old value | Set `JUPYTERHUB_SERVICE_NAME` to target or stop using env for container_name; **do not** conflate with public Host slug |
| H | `jupyterhub` | `jupyterhub--image-builder` | `jupyterhub--spawner--builder` | `jupyterhub--image-builder` | Build-only |
| H | `webprotege` | `webprotege` | `webprotege--webprotege--app` | `webprotege` | Manager `webprotege.generalSettings.apiBaseUrl` (`http://webprotege:8080`) |
| H | `webprotege` | `webprotege-mongodb` | `webprotege--mongodb--db` | `webprotege-mongodb` | Compose key often `wpmongo` |
| H | `website` | `scs-project-website--drupal` | `website--drupal--app` | old name | Optional stack |
| H | `website` | `scs-project-website--varnish` | `website--varnish--edge` | old name | |
| H | `website` | `scs-project-website--redis` | `website--redis--cache` | old name | |
| H | `website` | `scs-project-website--database` | `website--mariadb--db` **or drop** | old name | Prefer shared `core--mariadb--db` |
| Z | *(deferred)* | `{SERVICE_NAME}--varnish` | TBD — see Wave Z | old pattern | **Not in this migration cycle** |
| Z | *(deferred)* | `{SERVICE_NAME}--drupal` | TBD | old pattern | Needs [wisski-base-stack](https://github.com/soda-collections-objects-data-literacy/wisski-base-stack) release |
| Z | *(deferred)* | `{SERVICE_NAME}--redis` | TBD | old pattern | + Manager Portainer env + existing stacks |
| — | — | `jupyter-{username}` | **unchanged** | — | DockerSpawner; not platform scope |

**Platform rename count (excl. WissKI / notebooks):** 28 targets + 1 optional dead (`access-proxy`) + 1 no-op (`scs-manager--database`). WissKI is a **separate epic** (Wave Z), not counted here.

### 3.2 Networks

| Wave | Today | Target | Notes |
|------|-------|--------|-------|
| B | `nextcloud-mounter-net` | `core--rclone--net` | Or keep old `name:` long; Manager + sidecar must share |
| D | `reverse-proxy` | `core--traefik--net` | **Highest** operational blast. Prefer keep Docker network `name: reverse-proxy` forever and only document it as edge net; rename optional/late |
| H | `webprotege` (named net) | `webprotege--webprotege--net` | If still isolated |
| Z | `{SERVICE_NAME}_internal` | TBD (`wisski--{id}--net` or keep) | Deferred with Wave Z |

### 3.3 Named volumes (optional)

Prefer **keep external `name:`** on the existing volume (no data copy). Logical Compose keys may follow the new scheme later.

| Wave | Today (volume name) | Logical target key | Recommendation |
|------|---------------------|--------------------|----------------|
| C | `scs--database-data` | `core--mariadb--db-data` | Keep old `name:` |
| D | `scs--reverse-proxy-certificates` | `core--traefik--edge-certs` | Keep old `name:` (ACME) |
| E | `scs--portainer-data` | `core--portainer--app-data` | Keep old `name:` |
| B | `nextcloud-mounter-cache` | `core--rclone--sidecar-cache` | Keep old `name:` |
| H | `scs-manager--redis-data` etc. | `manager--redis--cache-data` … | Keep old `name:` |
| H | Nextcloud / ODS volumes | `nextcloud--…--data` | Keep old `name:` |
| H | `webprotege-data` | `webprotege--webprotege--app-data` | Keep old `name:` |
| F | `rdf4j-data`, `authproxy-data` | `opengdb--…--data` | Keep old `name:` |
| — | `scs--shared-data` | `core--shared--data` | Keep old `name:` |

### 3.4 Explicitly not renamed

| Item | Reason |
|------|--------|
| Public domains / Traefik `Host(...)` | Certs, OIDC redirects, bookmarks |
| **`COMPOSE_FILE` paths** | e.g. `scs-nextcloud-stack/…`, `00_custom_configs/scs-nextcloud-stack/…` — directory layout; **separate** refactor, never same PR as container DNS |
| Env **key** names (`KC_DB_HOST`, …) | **Values** change to new DNS; renaming keys is optional later |
| `KC_SERVICE_NAME=auth`, public Portainer slugs | URL fragments, not container DNS |
| Notebooks `jupyter-*` | Spawner convention |
| Submodule / stack folder names | Out of band |

---

## 4. Fallstrick-Klassen (immer alle prüfen)

Before **each** wave, search Today **and** planned Target; tick every class.

### 4.1 Environment (`.env` / `example-env`)

Central DNS knobs: **`SCS_CONTAINER_*`** (see [Naming vocabulary — Environment variables](naming-vocabulary.md#environment-variables-for-container-dns)). Scripts source `01_scripts/global/scs-container-names.bash`.

| Kind | Examples | Action |
|------|----------|--------|
| Docker DNS **values** | `SCS_CONTAINER_DATABASE`, `KC_DB_HOST=${SCS_CONTAINER_DATABASE}`, … | Flip once Target exists (+ alias) |
| JDBC / composed URLs | Keycloak `KC_DB_URL` uses `${SCS_CONTAINER_DATABASE}` | Covered if container var flips |
| Mounter | `NEXTCLOUD_MOUNTER_RC_URL` / `SCS_CONTAINER_NEXTCLOUD_MOUNTER` | PHP via `SodaScsDockerDns` |
| `JUPYTERHUB_SERVICE_NAME` | Used as **`container_name`** today | Decouple from public Host |
| Public slug env | `KC_SERVICE_NAME`, `SCS_PORTAINER_SERVICE_NAME` | **Do not** treat as container rename |
| **`COMPOSE_FILE=`** | File paths under stack dirs | **Do not** change when renaming containers |

### 4.2 Compose

- Service keys, `container_name`, `depends_on`, `networks`, volume keys  
- `extra_hosts`, `DJANGO_ALLOWED_HOSTS`, JVM `-Dhttp.proxyHost=scs--outproxy`  
- Traefik router/service **label IDs** (can lag; cosmetic/scripts)  
- `00_custom_configs/**` **and** already copied overrides in stack dirs (`start.sh` may skip overwrite)

### 4.3 `soda_scs_manager` config

| Key | Typical Today | Target after flip |
|-----|---------------|-------------------|
| `dbHost` | `scs--database` | `core--mariadb--db` |
| `triplestore.generalSettings.internalHost` | `http://scs--authproxy:8000` | `http://opengdb--authproxy--proxy:8000` |
| `webprotege.generalSettings.apiBaseUrl` | `http://webprotege:8080` | `http://webprotege--webprotege--app:8080` |
| `accessProxy.generalSettings.containerName` | `scs--access-proxy` | `core--accessproxy--proxy` or remove |

Also update on-disk copies:

- `scs-manager-stack/custom_configs/soda_scs_manager.settings.yml`
- `scs-manager-stack/volumes/drupal-root/custom_configs/…`
- **live** config in MariaDB (export before / import or `config:set` on cutover)

Portainer / Jupyter / Nextcloud **public** baseUrls in settings usually stay on HTTPS domains — still verify nothing points at old Docker DNS.

### 4.4 Code hardcodes (`soda_scs_manager` + scripts)

Prefer env/settings; remaining defaults live in `SodaScsDockerDns` and `scs-container-names.bash`.

| Location | Mechanism |
|----------|-----------|
| `SodaScsDockerDns` | `SCS_CONTAINER_*`, `INTERNAL_TS_BASE`, `NEXTCLOUD_MOUNTER_RC_URL` |
| `SodaScsServiceHelpers` / `SodaScsSqlComponentActions` | settings `dbHost` → env → default |
| `NextcloudMounterClient` | env / Settings.php → `SodaScsDockerDns::nextcloudMounterRcUrl()` |
| `SodaScsSettingsForm` | form defaults from `SodaScsDockerDns` |
| `start.sh`, `01_scripts/**` | source `scs-container-names.bash`, use `"${SCS_CONTAINER_DATABASE}"` etc. |
| OpenGDB / Keycloak / Nextcloud overrides | `${SCS_CONTAINER_*}` in connection env |

### 4.5 Ops / external

- Cron, systemd (`scs-nextcloud-mounts.service` — mostly paths, not DNS)  
- Health dashboard container listing  
- Portainer-deployed WissKI env (frozen `TS_*`)  
- Operator muscle memory (`docker compose logs scs--reverse-proxy`)

---

## 5. Mandatory procedure per wave

```text
1. Freeze + backup (DB + export soda_scs_manager.settings)
2. Ripgrep inventory for Today (and Target collisions)
3. Compose: add Target service + container_name; alias Today on shared network(s)
4. Recreate only affected containers
5. Smoke DNS: getent/curl Today AND Target from each consumer
6. Flip consumers: .env values, overrides, scripts → Target
7. Flip soda_scs_manager.settings + PHP defaults + custom YAML copies
8. Smoke Manager (DB provision, mounts, Portainer, SPARQL, WebProtégé API)
9. Soak; ripgrep Today == 0 in runtime paths; then remove alias
10. Docs + changelogs
```

### Alias pattern

```yaml
services:
  core--mariadb--db:
    container_name: core--mariadb--db
    networks:
      reverse-proxy:
        aliases:
          - scs--database   # Today — keep until cutover done
```

### Verification

```bash
OLD='scs--database'
NEW='core--mariadb--db'
rg -n -g '!**/node_modules/**' -g '!**/.git/**' -g '!**/vendor/**' "$OLD" .

docker compose exec manager--drupal--app getent hosts "$OLD"   # after manager rename; use Today name during early waves
docker compose exec scs-manager--drupal getent hosts "$NEW"

scs-drush config:get soda_scs_manager.settings dbHost
scs-drush config:get soda_scs_manager.settings triplestore.generalSettings.internalHost
scs-drush config:get soda_scs_manager.settings webprotege.generalSettings.apiBaseUrl
scs-drush config:get soda_scs_manager.settings accessProxy.generalSettings.containerName
scs-drush config:get soda_scs_manager.settings --format=yaml | rg -n 'scs--|webprotege:|authproxy|mounter|nextcloud--'
```

---

## 6. Wave plan (piecewise)

### Wave 0 — Prep

- [x] Env layer `SCS_CONTAINER_*` + scripts + `SodaScsDockerDns` (dev, 2026-09-08)
- [ ] Export `soda_scs_manager.settings` (prime)
- [x] Confirm: **no** `COMPOSE_FILE` path renames in container waves  

### Wave A — `core--echo--app`, `health--health--app`

- [x] Introduced with aliases `scs--echo` / `scs--health` (2026-09-08)
- [ ] Soak, then drop aliases

Low coupling; prove alias + recreate pattern.

### Wave B — `core--rclone--sidecar`

- [x] Alias `nextcloud-mounter` (both nets)
- [ ] Flip `NEXTCLOUD_MOUNTER_RC_URL` / `SCS_CONTAINER_NEXTCLOUD_MOUNTER` after soak
- [x] Network: keep `nextcloud-mounter-net` name initially  
- [x] Smoke: rc-API old+new DNS; `scs:nextcloud-status` reachable; reconcile mounted=5

### Wave C — `core--mariadb--db` ⚠

- [x] Alias `scs--database` (long soak); compose key + `container_name` = `core--mariadb--db`; volume still `scs--database-data` (dev, 2026-09-08)
- [x] `SCS_CONTAINER_DATABASE` / scripts / `start.sh` use the new name (`docker exec` is not aliased)
- [ ] Flip remaining `*_DB_HOST`, JDBC, `MYSQL_HOST`, Drupal `DB_HOST`, `dbHost`, PHP fallbacks after soak
- [ ] Smoke Keycloak, Manager, Nextcloud, phpMyAdmin, project DB CRUD  

### Wave D — `core--traefik--edge`

- [x] Alias `scs--reverse-proxy`; compose key + `container_name` = `core--traefik--edge` (dev, 2026-09-08)
- [x] Docker network `name: reverse-proxy` **unchanged**; cert volume still `scs--reverse-proxy-certificates`
- [x] Traefik **router** label IDs still `scs--reverse-proxy` (intentional lag)
- [ ] Soak, then drop alias; optionally rename router labels later

### Wave E — `core--portainer--app`, `dbms--*`

- [x] Aliases `scs--portainer` / `scs--phpmyadmin` / `scs--forward-auth` (dev, 2026-09-08)
- [x] Portainer volume still `scs--portainer-data`; Traefik router label IDs lag
- [x] Traefik `dbms-sso` still calls `http://scs--forward-auth:4181` (alias; no Traefik recreate)
- [ ] Soak, then flip middleware URL + drop aliases

### Wave F — `opengdb--*` ⚠ Manager + WissKI

- [x] Aliases `scs--rdf4j` / `scs--authproxy` / `scs--outproxy` / `scs--opengdb-proxy` (dev, 2026-09-08)
- [x] Submodule compose keys parked on profile `opengdb-legacy-keys`; new keys live in the override
- [x] `INTERNAL_TS_BASE` / Manager `internalHost` / WissKI `TS_*` still `http://scs--authproxy:8000`
- [x] `DJANGO_ALLOWED_HOSTS` includes both Today and Target
- [ ] Flip `internalHost` + WissKI `TS_*` + drop aliases after soak  

### Wave G — access-proxy

- [x] Confirmed dead: no Compose service, no running container (dev, 2026-09-08)
- [x] Removed `SCS_CONTAINER_ACCESS_PROXY` from env helper, `example-env`, Manager overrides
- [ ] Optional: delete leftover `accessProxy.*` from `soda_scs_manager.settings` if the module still stores it

### Wave H — one Compose env per cycle

Suggested order:

1. [x] `keycloak--keycloak--app` (alias `keycloak--keycloak`; Traefik router labels lag; public `KC_DOMAIN` unchanged)  
2. [x] `manager--drupal--app` / `manager--redis--cache` (aliases `scs-manager--drupal` / `scs-manager--redis`; Traefik router IDs lag; `scs-drush` host alias updated)  
3. [x] `nextcloud--*` all five (aliases keep nginx upstreams, `REDIS_HOST`, OnlyOffice `DocumentServerInternalUrl`; Traefik router IDs lag; `NEXTCLOUD_REDIS_HOST` still `nextcloud--redis`)  
4. [x] `jupyterhub--jupyterhub--app` / `jupyterhub--spawner--builder` (`JUPYTERHUB_SERVICE_NAME` = Target for hub_connect_ip; notebooks `jupyter-{user}` unchanged; Traefik router IDs lag)  
5. [x] `webprotege--webprotege--app` / `webprotege--mongodb--db` (aliases keep `apiBaseUrl` + `webprotege.mongodb.host=wpmongo`; Traefik label IDs lag)  
6. [ ] `website--*` if enabled — **skipped on this host** (stack not in live `COMPOSE_FILE`; prepare files later or leave until website is enabled)

Each: introduce+alias → flip env/scripts (`docker exec` / compose keys) → smoke → drop alias after soak.

### Wave H3 — Nextcloud (dev, 2026-09-08)

- [x] Compose keys + `container_name` for all five; aliases keep Today DNS
- [x] `SCS_CONTAINER_NEXTCLOUD` / `_REDIS` / `_EDGE` / `_ODS` / `_ODS_EDGE` flipped
- [x] `NEXTCLOUD_REDIS_HOST` still `nextcloud--redis`; nginx `upstream` / OnlyOffice `DocumentServerInternalUrl` still Today names
- [x] Traefik router label IDs lag (`nextcloud--nextcloud-reverse-proxy`, `nextcloud--onlyoffice-reverse-proxy`)
- [x] Volumes keep `name:` (`nextcloud-data`, `onlyoffice-data`, `onlyoffice-log`)
- [ ] Drop aliases + flip `REDIS_HOST` / nginx.conf / occ OnlyOffice internals after soak

### Wave H4 — JupyterHub (dev, 2026-09-08)

- [x] Compose keys + `container_name`: `jupyterhub--jupyterhub--app`, `jupyterhub--spawner--builder`
- [x] Alias `jupyterhub--jupyterhub` on `reverse-proxy`; builder is build-only (`replicas: 0`)
- [x] `JUPYTERHUB_SERVICE_NAME` + `SCS_CONTAINER_JUPYTERHUB` / `_BUILDER` flipped to Target
- [x] Traefik router label IDs lag (`jupyterhub--jupyterhub`)
- [x] Notebook containers `jupyter-{user}` unchanged
- [ ] Drop hub alias after soak

### Wave H5 — WebProtégé (dev, 2026-09-08)

- [x] Compose keys + `container_name`: `webprotege--webprotege--app`, `webprotege--mongodb--db`
- [x] Aliases `webprotege` (app), `wpmongo` + `webprotege-mongodb` (mongo)
- [x] `SCS_CONTAINER_WEBPROTEGE` / `_MONGODB` flipped; Manager `apiBaseUrl` still `http://webprotege:8080`
- [x] `webprotege.mongodb.host=wpmongo` unchanged (alias)
- [x] Volumes keep `name:` (`webprotege-data`, `mongodb-data`); network `name: webprotege`
- [x] Traefik router/service label IDs lag (`webprotege`, `webprotege-nocache`, …)
- [ ] Flip `apiBaseUrl` + `mongodb.host` + drop aliases after soak

### Wave Z — WissKI instances — **TODO / deferred**

**Not part of the current platform rename.** Leave running stacks as `{SERVICE_NAME}--{drupal|varnish|redis}` (e.g. `wisski-mit-nextcloud-mount--drupal`).

Why it is harder than Waves A–H:

1. **External Compose**, not root `COMPOSE_FILE`: [wisski-base-stack `docker-compose.yml`](https://github.com/soda-collections-objects-data-literacy/wisski-base-stack/blob/3.x/docker-compose.yml) (local checkout `repos/wisski-base-stack`). Container names are `${SERVICE_NAME}--drupal` / `--varnish` / `--redis`; Varnish `VARNISH_BACKEND_HOST=${SERVICE_NAME}--drupal`.
2. **Needs its own release** of `wisski-base-stack` (and likely Manager Portainer template / env wiring) before any live cutover.
3. **Many living stacks** via Portainer — rename is rolling redeploy, not one `docker compose up`.
4. **Scope token still open** — early draft used `proj-{id}--drupal--app`. Prefer something closer to Today’s `SERVICE_NAME`, e.g. `wisski--{id}--drupal--app` / `wisski--{id}--varnish--edge` / `wisski--{id}--redis--cache` (three segments, function vocabulary). Exact `{id}` mapping (slug vs Drupal project id vs current `SERVICE_NAME`) is undecided.

Checklist when we pick this up:

- [ ] Decide scope/id scheme (`wisski--{id}--*` vs `proj-{id}--*` vs keep `{SERVICE_NAME}--*` + only add function)
- [ ] Patch `wisski-base-stack` compose (`container_name`, `VARNISH_BACKEND_HOST`, Traefik label IDs, volume `name:` policy)
- [ ] Tag/release `wisski-base-stack`; point Manager/Portainer at the new tag
- [ ] Migration path for **existing** stacks (alias soak vs recreate-only for new projects)
- [ ] Scripts (`01_scripts/wisski/*`), docs, architecture inventory
- [ ] Do **not** conflate with public Hosts (`*.wisski.…`) or Nextcloud Team Folder labels

Until then: platform migration is done for shared stacks; WissKI stays on Today names.

---

## 7. PR slicing

| PR | Content |
|----|---------|
| 0 | Docs: this convention + tables |
| A… | Per wave: introduce Target + Today alias |
| *2 | Flip Env / scripts / Manager / PHP to Target |
| *3 | Remove Today alias after soak |

Never combine alias removal with unrelated features. Never mix container DNS renames with `COMPOSE_FILE` directory moves.

---

## 8. Rollback

1. Backup Compose + `.env` + settings export.  
2. While alias exists: revert flip commits only.  
3. After alias removed: **restore alias first**, then debug.  
4. Manager: restore `soda_scs_manager.settings`.  
5. WissKI: restore `TS_*` / SALZ or re-run tuning with old `INTERNAL_TS_BASE`.

---

## 9. Open decisions

1. Scope token for OpenGDB: `opengdb` (above) vs `ts` — prefer Compose-honest `opengdb`.  
2. Health: `health--health--app` (explicit) vs shorter — **keep explicit**.  
3. Docker network `reverse-proxy`: rename late / never?  
4. Alias soak duration (staging / prime)?  
5. Prime settings cutover: Drush update hook vs manual `config:set`?  
6. ~~Is `scs--access-proxy` dead?~~ Yes — removed from compose/env (Wave G).  
7. Confirm website keeps private MariaDB or moves to `core--mariadb--db` only.  
8. **WissKI / Wave Z (deferred):** Prefer `wisski--{id}--{drupal|varnish|redis}`-style names over `proj-{id}--*`. Exact `{id}` (current `SERVICE_NAME` slug vs numeric project id) and whether the third segment is software (`drupal`) or function (`app` / `edge` / `cache`) — decide in the `wisski-base-stack` release, not in this deployment cycle.

---

## See also

- [Naming vocabulary](naming-vocabulary.md)  
- [Architecture overview](architecture-overview.md)  
- [Glossary](../glossary.md)  
- [Nextcloud mount sidecar](nextcloud-mount-sidecar.md)  
- [WissKI stack](wisski-stack/index.md) — `internalHost`  
- [Pre-start steps](../initial-setup/pre-start-steps.md) — `start.sh` / DB bootstrap  
