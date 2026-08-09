#!/bin/bash
# Host preparation shared by stacks (paths must match Docker bind mounts).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Drupal / MariaDB snapshot bind mount (see docker-compose.yml). UID/GID 33 is
# www-data in the official Drupal image and matches snapshot dump/exec users.
SNAPSHOT_HOST_DIR="${SNAPSHOT_HOST_DIR:-/srv/backups/scs-manager/snapshots}"

echo "Ensuring SCS Manager snapshot directory exists: ${SNAPSHOT_HOST_DIR}"
sudo mkdir -p "${SNAPSHOT_HOST_DIR}"
sudo chown -R 33:33 "${SNAPSHOT_HOST_DIR}"
sudo chmod -R 775 "${SNAPSHOT_HOST_DIR}"

if sudo -u \#33 test -w "${SNAPSHOT_HOST_DIR}"; then
  echo "Snapshot directory is writable as UID 33 (container www-data)."
else
  echo "Warning: ${SNAPSHOT_HOST_DIR} is not writable as UID 33; snapshots may fail until permissions are fixed."
fi

# Shared bind for Nextcloud FUSE mounts (sidecar + consumers). Prefer the
# systemd unit for boot persistence; this keeps start.sh / pre-install green.
bash "${SCRIPT_DIR}/setup-nextcloud-mounts.sh"
