#!/usr/bin/env bash
# Truncate common application logs inside running containers (no data loss beyond log lines).
# Run from anywhere.
set -euo pipefail

if docker ps --format '{{.Names}}' | grep -qx 'nextcloud--nextcloud'; then
  docker exec --user www-data nextcloud--nextcloud sh -c '> /var/www/html/data/nextcloud.log'
  echo "Truncated nextcloud--nextcloud:/var/www/html/data/nextcloud.log"
else
  echo "Skip Nextcloud log (container nextcloud--nextcloud not running)."
fi

if docker ps --format '{{.Names}}' | grep -qx 'scs--database'; then
  docker exec scs--database sh -c '> /var/log/mysql/slow-query.log'
  echo "Truncated scs--database:/var/log/mysql/slow-query.log"
else
  echo "Skip MariaDB slow log (container scs--database not running)."
fi

echo
echo "Docker json-file container logs (docker compose logs) live on the host. To clear them you need"
echo "root on the host, then for each container: sudo truncate -s 0 \"\$(docker inspect -f '{{.LogPath}}' <name>)\""
