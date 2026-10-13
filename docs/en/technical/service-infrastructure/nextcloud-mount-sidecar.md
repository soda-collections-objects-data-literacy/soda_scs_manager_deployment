# Nextcloud Mount Sidecar

A dedicated `core--rclone--sidecar` container (alias `nextcloud-mounter` during naming migration) runs `rclone rcd` with
`SYS_ADMIN` and
`/dev/fuse`. It creates one WebDAV/FUSE mount per platform user under
`${NEXTCLOUD_MOUNTS_ROOT}/<machine-name>`, and one per project with JupyterHub
under `${NEXTCLOUD_MOUNTS_ROOT}/_projects/<gid>/<project-label>` (default root
`/var/lib/scs/nextcloud-mounts`). Consumer containers (WissKI, Jupyter) bind
these paths with `rslave` propagation and never receive FUSE capabilities or
rc-API access.

## Architecture

```text
Host: /var/lib/scs/nextcloud-mounts   (self-bound rshared)
 ├── _disabled/          ← empty fallback bind for stacks without a project folder
 ├── _projects/          ← 33:33; project mounts of the service account scs-jupyter
 │    └── <gid>/
 │         └── <project-label>/   ← rclone FUSE mount (one Team Folder)
 ├── <user-a>/            ← rclone FUSE mount (whole Drive)
 │    └── <project-label>/
 └── <user-b>/

nextcloud-mounter (sidecar)
  rclone rcd :5572
  SYS_ADMIN + /dev/fuse
  bind: host root → /mnt/nextcloud (rshared)
  nets: nextcloud-mounter-net (internal) + reverse-proxy (WebDAV egress)
        ▲
        │ mount/unmount via rc-API (Basic Auth)
 SCS Manager (Drupal) — only consumer of the rc-API
  nets: … + nextcloud-mounter-net
  bind: host root → /mnt/nextcloud-mounts (rslave)
```

Design rules:

- One sidecar FUSE mount per platform user (whole Drive under
  `${NEXTCLOUD_MOUNTS_ROOT}/<machine-name>`).
- **WissKI** binds only the **project Team Folder** subdirectory
  (`…/<user>/<project-label>` → `/opt/drupal/private-files/nextcloud` =
  `private://nextcloud`), with `NEXTCLOUD_MOUNT_MODE=external`.
- **Jupyter** binds the **project mounts** of the Keycloak projects the user
  belongs to (`…/_projects/<gid>/<project-label>` →
  `/home/jovyan/nextcloud/<project-label>`, `rslave`; notebook user is in GID
  `33` for www-data ownership on the FUSE tree). Project groups are integer
  names (`gid = entityId + 10000`). Only projects with JupyterHub have a
  project mount.
- Project mounts use the Nextcloud service account `scs-jupyter` (group
  `scs-project-mounts`), not a member's app password. The account sees a Team
  Folder only while the project has JupyterHub: the Manager adds the group to
  the folder when JupyterHub is added and removes it when JupyterHub goes.
- Lifecycle owner is SCS Manager: `NextcloudMountManager` (user mounts) and
  `NextcloudProjectMountManager` (project mounts). Drupal cron reconciles both
  at most once per minute, but `automated_cron` only fires every few hours
  after a page request. The host timer `scs-nextcloud-mount-reconcile.timer`
  runs `scs:nextcloud-reconcile` and `scs:nextcloud-project-reconcile` every
  minute (see Host preparation). The user reconciler leaves `_projects/` alone.
- Host bind with `rshared` / consumers with `rslave` (named volumes cannot
  propagate FUSE).
- Empty fallback: `${NEXTCLOUD_MOUNTS_ROOT}/_disabled` (owned `33:33`) when no
  project folder is available yet.

## Host preparation (once)

```bash
cd /var/www/deploy/soda_scs_manager_deployment

# One-shot / idempotent
bash 01_scripts/global/setup-nextcloud-mounts.sh

# Persist across reboots (preferred)
sudo cp 01_scripts/global/scs-nextcloud-mounts.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now scs-nextcloud-mounts.service

findmnt -o PROPAGATION --target /var/lib/scs/nextcloud-mounts
# must contain "shared"

# Reconcile user and project mounts every minute (Drupal cron is too rare)
sudo cp 01_scripts/global/scs-nextcloud-mount-reconcile.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now scs-nextcloud-mount-reconcile.timer
journalctl -u scs-nextcloud-mount-reconcile.service -n 20
```

`start.sh` aborts if the mounts root is missing or not `shared`.

## Environment

In `.env` (see `example-env`):

```bash
NEXTCLOUD_MOUNTS_ROOT=/var/lib/scs/nextcloud-mounts
NEXTCLOUD_MOUNTER_RC_USER=scs-manager
NEXTCLOUD_MOUNTER_RC_PASS=<openssl rand -hex 32>
```

SCS Manager also receives (via stack override):

```bash
NEXTCLOUD_MOUNTER_RC_URL=http://nextcloud-mounter:5572
NEXTCLOUD_MOUNTER_RC_USER / NEXTCLOUD_MOUNTER_RC_PASS
NEXTCLOUD_MOUNTS_ROOT
NEXTCLOUD_PROJECT_MOUNT_USER=scs-jupyter
NEXTCLOUD_PROJECT_MOUNT_APP_PASSWORD=<app password>
NEXTCLOUD_PROJECT_MOUNT_GROUP=scs-project-mounts
```

Without `NEXTCLOUD_PROJECT_MOUNT_USER` and `_APP_PASSWORD` the Manager skips
project mounts. Create the account (idempotent) and one app password:

```bash
docker exec -u www-data -e CREATE_APP_PASSWORD=1 nextcloud--nextcloud--app \
  bash /docker-entrypoint-hooks.d/post-installation/create-project-mount-user.sh
```

Every run with `CREATE_APP_PASSWORD=1` creates another app password; revoke
old ones in the Nextcloud user settings of `scs-jupyter`.

Keep these in `00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml`
(copied to `scs-manager-stack/` by `start.sh`): attach `scs-manager--drupal` to
`nextcloud-mounter-net`, `depends_on: nextcloud-mounter`, and bind
`${NEXTCLOUD_MOUNTS_ROOT}` → `/mnt/nextcloud-mounts` with `rslave`.

## Start / health

```bash
docker compose up -d core--rclone--sidecar
docker compose ps core--rclone--sidecar
# Healthy; no host port published for :5572
```

From the SCS Manager container:

```bash
docker exec scs-manager--drupal curl -sf -u "$NEXTCLOUD_MOUNTER_RC_USER:$NEXTCLOUD_MOUNTER_RC_PASS" \
  -X POST http://nextcloud-mounter:5572/core/pid
```

Or via Drush inside Manager:

```bash
scs-drush scs:nextcloud-status
scs-drush scs:nextcloud-reconcile
# per user: scs:nextcloud-mount / scs:nextcloud-unmount --user=<name>

scs-drush scs:nextcloud-project-status
scs-drush scs:nextcloud-project-reconcile
# per project: scs:nextcloud-project-mount / scs:nextcloud-project-unmount --project=<id|machine-name>
```

WissKI containers must **not** resolve or reach `nextcloud-mounter:5572`
(they are not on `nextcloud-mounter-net`).

## Consumers

### WissKI (project Team Folder)

SCS Manager provisions each stack with:

| Env | Typical value |
|---|---|
| `NEXTCLOUD_MOUNT_MODE` | `external` |
| `NEXTCLOUD_USER_MOUNT_SOURCE` | `/var/lib/scs/nextcloud-mounts/<owner>/<project-label>` (or `…/_disabled`) |

`wisski-base-stack` binds that host path to
`/opt/drupal/private-files/nextcloud` (`rslave`). The image enables
`nextcloud_webdav_mount` with `operation_mode=external` and
`external_mount_path=private://nextcloud` (status only — no in-container rclone,
no app passwords in the WissKI stack).

Existing stacks need a re-deploy to pick up the external bind after migration
from sync mode.

### JupyterHub (project Team Folders)

`jupyterhub/jupyterhub/jupyterhub_config.py` reads Keycloak project groups from
OIDC `groups` (integer names ≥ `10000`) and binds every live mount below
`_projects/<gid>/`:

`${NEXTCLOUD_MOUNTS_ROOT}/_projects/<gid>/<project-label>` →
`/home/jovyan/nextcloud/<project-label>`

with `rslave`. Personal Drive content and non-project folders (e.g. `Documents`,
`SCS-Share`) are not mounted, and members do not need a Drive mount of their
own. The folder name comes from the mount directory, so the Hub needs no
Keycloak Admin API access. The Hub override passes `NEXTCLOUD_MOUNTS_ROOT` and
bind-mounts the mounts root (`rslave`). If none of the user's projects has a
project mount, `_disabled` is bound to `/home/jovyan/nextcloud`.

Project mount flow in the Manager:

1. Adding JupyterHub to a project sets the Team Folder groups to
   `[<gid>, scs-project-mounts]`, then mounts it. If the mount is not ready,
   the next reconcile retries it.
2. Before mounting, the Manager checks with `PROPFIND` that `scs-jupyter` sees
   the folder. It never mounts an invisible folder, because rclone would then
   create a plain folder of that name in the service account's own Drive.
3. Renaming the project remounts under the new label, after the Team Folder is
   renamed.
4. Removing JupyterHub unmounts and removes `scs-project-mounts` from the
   folder; deleting the project unmounts before the Team Folder is deleted.
   Files stay in Nextcloud.

Mount options: `CacheMode=writes`, `UID/GID=33`, `Umask=002`, `DirCacheTime=30s`.
Changes made in the Nextcloud web UI appear in notebooks after about 30 s; when
the same file is edited in both places at once, the last write wins. In
Nextcloud, changes made from notebooks appear as `scs-jupyter`.

#### Respawn after project create / join (not hot)

Mounts are fixed when the notebook container is **spawned**. Adding JupyterHub
to a project or accepting a membership of a project with JupyterHub does
**not** add folders to a running Lab.

1. In SCS Manager, users see a warning with a link to stop the notebook
   (`/soda-scs-manager/jupyter/restart-notebook`), or they can **Stop** from
   the Jupyter card health icon.
2. The confirm form **stops** the notebook server and warns that **unsaved
   notebook work will be lost** (home volume and Nextcloud files are kept).
3. The user opens JupyterHub and chooses **Start My Server** so the Hub
   re-reads Keycloak project groups and binds the new Team Folders.

Stopping alone does not remount; a Hub spawn is required.

## Secret rotation

1. Set a new `NEXTCLOUD_MOUNTER_RC_PASS` in `.env`.
2. `docker compose up -d core--rclone--sidecar scs-manager--drupal`
3. Confirm Manager can still call `core/pid` (or `scs-drush scs:nextcloud-status`).

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `Transport endpoint is not connected` | Sidecar crashed; stale FUSE node | `docker compose restart core--rclone--sidecar`; then `scs-drush scs:nextcloud-reconcile` |
| Mount empty in running WissKI | Source dir missing at stack start, or wrong `NEXTCLOUD_USER_MOUNT_SOURCE` | Ensure owner mount + project folder exist; redeploy stack with correct source |
| WissKI shows disconnected / not mounted | Module not in `external` mode, or bind still `_disabled` | Check `NEXTCLOUD_MOUNT_MODE` / `operation_mode`; redeploy after Team Folder exists |
| `start.sh` aborts on propagation | Host bind not rshared | Re-run setup script / enable systemd unit |
| rc-API 401 | Password drift between sidecar and Manager | Align `.env` and recreate both services |
| Manager cannot resolve `nextcloud-mounter` | Not on `nextcloud-mounter-net` | Fix override (network + `depends_on`) and recreate Manager |
| Project folder missing in a notebook | Project has no JupyterHub, mount not ready, or server started before the mount | `scs-drush scs:nextcloud-project-status`; then stop and start the notebook |
| Project mount fails, log says "not visible to the project mount account" | Team Folder lacks `scs-project-mounts`, or a folder of that name exists in `scs-jupyter`'s own Drive | Check the folder's groups in Nextcloud Team Folders; remove stray folders from `scs-jupyter`'s files |
| Project mounts skipped silently | `NEXTCLOUD_PROJECT_MOUNT_*` missing in the Manager container | Set them in `.env` and recreate the Manager |

## Backup

Live FUSE mounts are excluded from host backups (`backup-containers.sh`).
Nextcloud remains the source of truth.

## Related

- [Post-configuration checklist](../post-configuration/checklist.md#nextcloud-mount-sidecar)
- [WissKI stack](wisski-stack/index.md#nextcloud-external-mount)
- `nextcloud_webdav_mount` module: `operation_mode=external` (passive path/status)
- Manager services: `NextcloudMounterClient`, `NextcloudMountManager`, `NextcloudProjectMountManager`, Drush `scs:nextcloud-*`
