#!/bin/bash
# Prepare the shared host bind for Nextcloud FUSE mounts (rshared propagation).
# Prefer enabling the systemd unit (see docs/service-infrastructure/nextcloud-mount-sidecar.md).
# This script is safe to re-run (idempotent).

set -euo pipefail

NEXTCLOUD_MOUNTS_ROOT="${NEXTCLOUD_MOUNTS_ROOT:-/var/lib/scs/nextcloud-mounts}"

echo "Ensuring Nextcloud mounts root exists: ${NEXTCLOUD_MOUNTS_ROOT}"
sudo mkdir -p "${NEXTCLOUD_MOUNTS_ROOT}"
sudo mkdir -p "${NEXTCLOUD_MOUNTS_ROOT}/_disabled"
sudo chown root:root "${NEXTCLOUD_MOUNTS_ROOT}"
sudo chmod 755 "${NEXTCLOUD_MOUNTS_ROOT}"
sudo chown 33:33 "${NEXTCLOUD_MOUNTS_ROOT}/_disabled"
sudo chmod 755 "${NEXTCLOUD_MOUNTS_ROOT}/_disabled"

# Self-bind so propagation flags apply to the mount tree.
# findmnt --target walks parents; compare TARGET to the path itself.
current_target="$(findmnt -n -o TARGET --target "${NEXTCLOUD_MOUNTS_ROOT}" | head -1 || true)"
if [[ "${current_target}" != "${NEXTCLOUD_MOUNTS_ROOT}" ]]; then
  echo "Binding ${NEXTCLOUD_MOUNTS_ROOT} onto itself..."
  sudo mount --bind "${NEXTCLOUD_MOUNTS_ROOT}" "${NEXTCLOUD_MOUNTS_ROOT}"
fi

sudo mount --make-rshared "${NEXTCLOUD_MOUNTS_ROOT}"

propagation="$(findmnt -n -o PROPAGATION --target "${NEXTCLOUD_MOUNTS_ROOT}" | head -1 || true)"
current_target="$(findmnt -n -o TARGET --target "${NEXTCLOUD_MOUNTS_ROOT}" | head -1 || true)"
echo "Mount ${current_target} propagation: ${propagation}"
if [[ "${current_target}" != "${NEXTCLOUD_MOUNTS_ROOT}" || "${propagation}" != *shared* ]]; then
  echo "Error: ${NEXTCLOUD_MOUNTS_ROOT} is not a shared self-bind (target=${current_target}, prop=${propagation})" >&2
  exit 1
fi

echo "Nextcloud mounts root is ready (rshared)."
