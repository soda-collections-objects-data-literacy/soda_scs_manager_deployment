# Nextcloud Mount Sidecar

A dedicated `nextcloud-mounter` container runs `rclone rcd` with `SYS_ADMIN` and
`/dev/fuse`. It creates one WebDAV/FUSE mount per platform user under
`${NEXTCLOUD_MOUNTS_ROOT}` (default `/var/lib/scs/nextcloud-mounts/<machine-name>`).
Consumer containers (WissKI, Jupyter) bind that path with `rslave` propagation
and never receive FUSE capabilities or rc-API access.

## Architecture

```text
Host: /var/lib/scs/nextcloud-mounts   (self-bound rshared)
 ├── <user-a>/   ← rclone FUSE mount
 └── <user-b>/

nextcloud-mounter (sidecar)
  rclone rcd :5572
  SYS_ADMIN + /dev/fuse
  nets: nextcloud-mounter-net (internal) + reverse-proxy (WebDAV egress)
        ▲
        │ mount/unmount via rc-API (Basic Auth)
 SCS Manager (Drupal) — only consumer of the rc-API
```

Design rules (see `plans/00-OVERVIEW.md`):

- One sidecar FUSE mount per platform user (whole Drive under `${NEXTCLOUD_MOUNTS_ROOT}/<user>`).
- **WissKI** binds only the **project Team Folder** subdirectory
  (`…/<user>/<project-label>` → `/opt/drupal/private-files/nextcloud` =
  `private://nextcloud`), matching project-centric SCS.
- Lifecycle owner is SCS Manager.
- Host bind with `rshared` / consumers with `rslave` (named volumes cannot propagate FUSE).

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

WissKI containers must **not** resolve or reach `nextcloud-mounter:5572`
(they are not on `nextcloud-mounter-net`).

## Secret rotation

1. Set a new `NEXTCLOUD_MOUNTER_RC_PASS` in `.env`.
2. `docker compose up -d nextcloud-mounter scs-manager--drupal`
3. Confirm Manager can still call `core/pid`.

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `Transport endpoint is not connected` | Sidecar crashed; stale FUSE node | `docker compose restart nextcloud-mounter`; Manager reconciler remounts |
| Mount empty in running WissKI | Source dir missing at stack start, or wrong `NEXTCLOUD_USER_MOUNT_SOURCE` | Ensure per-user dir exists; redeploy stack with correct source |
| `start.sh` aborts on propagation | Host bind not rshared | Re-run setup script / enable systemd unit |
| rc-API 401 | Password drift between sidecar and Manager | Align `.env` and recreate both services |

## Backup

Live FUSE mounts are excluded from host backups (`backup-containers.sh`).
Nextcloud remains the source of truth.
