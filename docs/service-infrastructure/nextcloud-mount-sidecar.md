# Nextcloud Mount Sidecar

A dedicated `nextcloud-mounter` container runs `rclone rcd` with `SYS_ADMIN` and
`/dev/fuse`. It creates one WebDAV/FUSE mount per platform user under
`${NEXTCLOUD_MOUNTS_ROOT}/<machine-name>` (default root
`/var/lib/scs/nextcloud-mounts`). Consumer containers (WissKI, Jupyter) bind that
path with `rslave` propagation and never receive FUSE capabilities or rc-API
access.

## Architecture

```text
Host: /var/lib/scs/nextcloud-mounts   (self-bound rshared)
 ├── _disabled/          ← empty fallback bind for stacks without a project folder
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
- **Jupyter** binds only **Keycloak project Team Folders** the user belongs to
  (`…/<user>/<project-label>` → `/home/jovyan/nextcloud/<project-label>`,
  `rslave`; notebook user is in GID `33` for www-data ownership on the FUSE tree).
  Project groups are integer names (`entityId + 10000`); Hub resolves each
  group’s `label` attribute via Keycloak Admin API at spawn.
- Lifecycle owner is SCS Manager (`NextcloudMountManager` reconciler ~1 min cron).
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
```

Keep these in `00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml`
(copied to `scs-manager-stack/` by `start.sh`): attach `scs-manager--drupal` to
`nextcloud-mounter-net`, `depends_on: nextcloud-mounter`, and bind
`${NEXTCLOUD_MOUNTS_ROOT}` → `/mnt/nextcloud-mounts` with `rslave`.

## Start / health

```bash
docker compose up -d nextcloud-mounter
docker compose ps nextcloud-mounter
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
OIDC `groups` (integer names ≥ `10000`), resolves each group’s `label`
attribute, and binds

`${NEXTCLOUD_MOUNTS_ROOT}/<username>/<project-label>` →
`/home/jovyan/nextcloud/<project-label>`

with `rslave`. Personal Drive content and non-project folders (e.g. `Documents`,
`SCS-Share`) are not mounted. The Hub override passes `NEXTCLOUD_MOUNTS_ROOT`,
`KC_URL` / `KC_REALM`, and bootstrap admin credentials for label lookup, and
bind-mounts the mounts root (`rslave`) so existence checks see the host FUSE
tree. If no project folder is available, `_disabled` is bound to
`/home/jovyan/nextcloud`.

#### Respawn after project create / join (not hot)

Mounts are fixed when the notebook container is **spawned**. Creating a project
or accepting a membership does **not** add folders to a running Lab.

1. In SCS Manager, users see a warning with a link to **Restart Jupyter**
   (`/soda-scs-manager/jupyter/restart-notebook`), also in the main menu.
2. The confirm form **stops** the notebook server and warns that **unsaved
   notebook work will be lost** (home volume and Nextcloud files are kept).
3. The user opens JupyterHub and chooses **Start My Server** so the Hub
   re-reads Keycloak project groups and binds the new Team Folders.

Stopping alone does not remount; a Hub spawn is required.

## Secret rotation

1. Set a new `NEXTCLOUD_MOUNTER_RC_PASS` in `.env`.
2. `docker compose up -d nextcloud-mounter scs-manager--drupal`
3. Confirm Manager can still call `core/pid` (or `scs-drush scs:nextcloud-status`).

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `Transport endpoint is not connected` | Sidecar crashed; stale FUSE node | `docker compose restart nextcloud-mounter`; then `scs-drush scs:nextcloud-reconcile` |
| Mount empty in running WissKI | Source dir missing at stack start, or wrong `NEXTCLOUD_USER_MOUNT_SOURCE` | Ensure owner mount + project folder exist; redeploy stack with correct source |
| WissKI shows disconnected / not mounted | Module not in `external` mode, or bind still `_disabled` | Check `NEXTCLOUD_MOUNT_MODE` / `operation_mode`; redeploy after Team Folder exists |
| `start.sh` aborts on propagation | Host bind not rshared | Re-run setup script / enable systemd unit |
| rc-API 401 | Password drift between sidecar and Manager | Align `.env` and recreate both services |
| Manager cannot resolve `nextcloud-mounter` | Not on `nextcloud-mounter-net` | Fix override (network + `depends_on`) and recreate Manager |

## Backup

Live FUSE mounts are excluded from host backups (`backup-containers.sh`).
Nextcloud remains the source of truth.

## Related

- [Post-configuration checklist](../post-configuration/checklist.md#nextcloud-mount-sidecar)
- [WissKI stack](wisski-stack/index.md#nextcloud-external-mount)
- `nextcloud_webdav_mount` module: `operation_mode=external` (passive path/status)
- Manager services: `NextcloudMounterClient`, `NextcloudMountManager`, Drush `scs:nextcloud-*`
