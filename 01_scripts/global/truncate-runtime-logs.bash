#!/usr/bin/env bash
# Truncate common application logs inside running containers (no data loss beyond log lines).
# Run from anywhere.
set -euo pipefail

# Docker DNS names from .env (naming migration).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scs-container-names.bash"

if docker ps --format '{{.Names}}' | grep -qx "${SCS_CONTAINER_NEXTCLOUD}"; then
  docker exec --user www-data "${SCS_CONTAINER_NEXTCLOUD}" sh -c '> /var/www/html/data/nextcloud.log'
  echo "Truncated ${SCS_CONTAINER_NEXTCLOUD}:/var/www/html/data/nextcloud.log"
else
  echo "Skip Nextcloud log (container ${SCS_CONTAINER_NEXTCLOUD} not running)."
fi

if docker ps --format '{{.Names}}' | grep -qx "${SCS_CONTAINER_DATABASE}"; then
  docker exec "${SCS_CONTAINER_DATABASE}" sh -c '> /var/log/mysql/slow-query.log'
  echo "Truncated ${SCS_CONTAINER_DATABASE}:/var/log/mysql/slow-query.log"
else
  echo "Skip MariaDB slow log (container ${SCS_CONTAINER_DATABASE} not running)."
fi

echo
echo "Docker json-file container logs (docker compose logs) live on the host. To clear them you need"
echo "root on the host, then for each container: sudo truncate -s 0 \"\$(docker inspect -f '{{.LogPath}}' <name>)\""
