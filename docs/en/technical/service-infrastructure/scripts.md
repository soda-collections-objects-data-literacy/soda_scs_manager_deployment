# Scripts catalogue

Operational scripts live under `01_scripts/`. Run them from the **repo root** unless a script says otherwise. Shared container DNS defaults: `01_scripts/global/scs-container-names.bash` (sourced after `.env`).

Related: [Infrastructure inventory](inventory.md), [Custom configs](custom-configs.md), [Pre-start steps](../initial-setup/pre-start-steps.md), [Maintenance](../maintenance/index.md).

## Lifecycle overview

| Phase | Entry | What runs |
|-------|-------|-----------|
| First host prep | systemd units + `setup-nextcloud-mounts.sh` | FUSE mount root, snapshot dirs |
| Bootstrap | `./start.sh` | Network, copy overrides, start MariaDB, all `**/pre-install.sh` |
| Day-2 update | `01_scripts/global/update-stack.bash` | Fetch/FF, rebuild/recreate; `--prime` for production |
| Docs publish | `01_scripts/global/build-docs.bash` | Zensical DE+EN → `./site` (`core--docs--app`) |
| Backup | `01_scripts/global/backup-all-services.bash` | Calls per-stack backup scripts → `/srv/backups/` |
| Release push | `01_scripts/global/push-release-plan.bash` | Executes `plans/push-plan.txt` after `/scs-release-prep` |

---

## Global (`01_scripts/global/`)

| Script / unit | Effect | When |
|---------------|--------|------|
| `pre-install.sh` | Ensures snapshot host dir (`/srv/backups/scs-manager/snapshots`, UID 33); calls Nextcloud mounts setup | `start.sh` |
| `setup-nextcloud-mounts.sh` | Idempotent rshared bind of `NEXTCLOUD_MOUNTS_ROOT` | Manual / pre-install; prefer systemd |
| `scs-container-names.bash` | Defaults for `SCS_CONTAINER_*` | Sourced by ops scripts |
| `backup-functions.bash` | Shared backup helpers (retention, volume tar) | Sourced by backup scripts |
| `backup-all-services.bash` | Runs every stack backup script | Manual / cron |
| `build-docs.bash` | Build docs into `site/` for `core--docs--app` | Manual after doc changes |
| `update-stack.bash` | Check/apply submodule + compose changes; `--prime` path | Manual |
| `push-release-plan.bash` | Push commits/tags from `plans/push-plan.txt` (one SSH passphrase) | Manual |
| `php-security-mitigation.bash` | Audit/apply/revert temporary PHP CVE mitigations in containers | Manual |
| `truncate-runtime-logs.bash` | Truncate Nextcloud + MariaDB slow logs inside containers | Manual |
| `delete.sh` | `compose down` + remove named volumes (**destructive**) | Manual only |

### Systemd units

Copy from `01_scripts/global/` to `/etc/systemd/system/`, then `daemon-reload` and `enable --now`.

| Unit | Effect |
|------|--------|
| `scs-nextcloud-mounts.service` | Boot-persistent shared bind for FUSE mounts |
| `scs-nextcloud-mount-reconcile.service` + `.timer` | `drush scs:nextcloud-reconcile` + project reconcile + heartbeat (every ~1 min) |
| `scs-demo-queue.service` + `.timer` | `drush queue:run soda_scs_manager_demo` + heartbeat |
| `scs-wisski-update-queue.service` + `.timer` | `drush queue:run soda_scs_manager_wisski_update` + heartbeat |

Heartbeats feed `drush scs:check` / the Manager status report so a missing timer is visible.

---

## Per stack

### Database

| Script | Effect | When |
|--------|--------|------|
| `database/db-snapshot.bash` | `mariadb-dump` (+ optional tar) for one database | Manual / `update-stack --prime` |

### Keycloak

| Script | Effect | When |
|--------|--------|------|
| `keycloak/pre-install.sh` | Create KC DB/user; `envsubst` realm tpl → `keycloak/import/` | `start.sh` |
| `keycloak/keycloak-backup.bash` | Backup Keycloak database | Backup orchestrator |

### SCS Manager

| Script | Effect | When |
|--------|--------|------|
| `scs-manager-stack/pre-install.sh` | Manager DB/user; generate OpenID client YAML into `scs-manager-stack/custom_configs/` | `start.sh` |
| `scs-manager-stack/scs-manager-backup.bash` | DB + volumes (maintenance mode) | Backup |
| `scs-manager-stack/fix-www-data-shared-edit.bash` | setgid/ACL on custom module/theme for shared edit | Manual (root) |
| `scs-manager-stack/cleanup.sh` | Tear down Manager DB/user/OIDC file (**destructive**) | Manual |

### Nextcloud

| Script | Effect | When |
|--------|--------|------|
| `scs-nextcloud-stack/pre-install.sh` | Nextcloud DB/user/grants | `start.sh` |
| `scs-nextcloud-stack/start-services.bash` / `stop-services.bash` | Start/stop Drive containers alone | Manual |
| `scs-nextcloud-stack/nextcloud-backup.bash` | DB + volumes (used by `backup-all`) | Backup |
| `scs-nextcloud-stack/backup-nextcloud.bash` | Alternate backup with maintenance mode | Backup |
| `scs-nextcloud-stack/restore-nextcloud.bash` | Restore DB + data volume | Manual |
| `scs-nextcloud-stack/apply-nextcloud-proxy-and-region.bash` | `occ` trusted proxies, overwrite URLs, phone region | Manual / post-config |
| `scs-nextcloud-stack/configure-nextcloud-email.bash` | SMTP from `.env` via `occ` | Manual |
| `scs-nextcloud-stack/fix-onlyoffice-jwt.bash` | Align OnlyOffice JWT NC ↔ Document Server | Manual |
| `scs-nextcloud-stack/fix-nextcloud-warnings.bash` | Combined warning fix (proxy, AppAPI, repair) | Manual |
| `scs-nextcloud-stack/run-nextcloud-repair.bash` | `maintenance:repair` + missing indices | Manual |
| `scs-nextcloud-stack/clean-nextcloud.bash` | Tear down NC + drop DB (**destructive**) | Manual |

### JupyterHub

| Script | Effect | When |
|--------|--------|------|
| `jupyterhub/pre-install.sh` | Download/extract OpenRefine into hub share | `start.sh` |
| `jupyterhub/jupyterhub-backup.bash` | Hub volumes (+ group map / user vols) | Backup |

### OpenGDB

| Script | Effect | When |
|--------|--------|------|
| `open_gdb/open_gdb-backup.bash` | RDF4J + authproxy volumes | Backup |
| `open_gdb/migrate-repositories-to-lmdb.py` | Migrate RDF4J repos NativeStore → LMDB | Manual migration |

### WebProtégé

| Script | Effect | When |
|--------|--------|------|
| `webprotege/webprotege-backup.bash` | MongoDB + app volumes | Backup |
| `webprotege/configure-oidc.bash` | Write `WEBPROTEGE_OIDC_*` into `.env` and recreate | Manual |

### Project website

| Script | Effect | When |
|--------|--------|------|
| `scs-project-website-stack/pre-install.sh` | Website DB/user | `start.sh` (if stack enabled) |
| `scs-project-website-stack/backup.sh` | DB + volumes | Backup |
| `scs-project-website-stack/uninstall.sh` | Remove generated Varnish config dir | Manual |

### WissKI (Portainer instances)

| Script | Effect | When |
|--------|--------|------|
| `wisski/apply-performance-tuning.bash` | Live-tune PHP-FPM / Varnish / triplestore URLs on a running instance | Manual |

---

## Destructive scripts

Treat as last resort; they drop data or tear down stacks:

- `01_scripts/global/delete.sh`
- `01_scripts/scs-manager-stack/cleanup.sh`
- `01_scripts/scs-nextcloud-stack/clean-nextcloud.bash`
