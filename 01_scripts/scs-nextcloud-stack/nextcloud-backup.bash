#!/bin/bash

# Backup script for Nextcloud.
# Backs up database and volumes, with maintenance mode support.
# Run from repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$ROOT_DIR"

# Load environment variables.
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Source common backup functions.
source "${SCRIPT_DIR}/../global/backup-functions.bash"

# Check required env vars.
if [ -z "${SCS_DB_ROOT_PASSWORD:-}" ]; then
    echo "Error: SCS_DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

# Configuration.
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_BACKUP_DIR="/srv/backups"
NEXTCLOUD_BACKUP_DIR="${BASE_BACKUP_DIR}/nextcloud"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/nextcloud"
DB_CONTAINER="scs--database"
DB_ROOT_PASSWORD="${SCS_DB_ROOT_PASSWORD}"
NEXTCLOUD_DB_NAME="${NEXTCLOUD_DB_NAME:-nextcloud}"
NC_CONTAINER="nextcloud--nextcloud"

# Create backup directories.
mkdir -p "$NEXTCLOUD_BACKUP_DIR"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

# Initialize maintenance mode flag.
NC_MAINTENANCE_ENABLED=false

# Trap handler to ensure maintenance mode is disabled on exit.
cleanup_maintenance_mode() {
    if [ "$NC_MAINTENANCE_ENABLED" = true ]; then
        echo ""
        echo "Cleaning up: Disabling Nextcloud maintenance mode..."
        docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --off > /dev/null 2>&1 || true
    fi
}
trap cleanup_maintenance_mode EXIT

echo "=========================================="
echo "Backing up Nextcloud"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $NEXTCLOUD_BACKUP_DIR"
echo ""

# Enable maintenance mode.
if docker ps --format "{{.Names}}" | grep -q "^${NC_CONTAINER}$"; then
    echo "  Enabling Nextcloud maintenance mode..."
    if docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --on > /dev/null 2>&1; then
        echo "  ✓ Maintenance mode enabled."
        NC_MAINTENANCE_ENABLED=true
    else
        echo "  Warning: Could not enable maintenance mode. Continuing anyway."
        NC_MAINTENANCE_ENABLED=false
    fi
else
    echo "  Warning: Nextcloud container not running. Skipping maintenance mode."
    NC_MAINTENANCE_ENABLED=false
fi

# Backup database.
if [ -z "$NEXTCLOUD_DB_NAME" ]; then
    echo "  Error: NEXTCLOUD_DB_NAME is empty after default assignment."
    exit 1
fi

if ! backup_database "$NEXTCLOUD_DB_NAME" "$NEXTCLOUD_BACKUP_DIR" "nextcloud-db" "$TIMESTAMP" "$DB_CONTAINER" "$DB_ROOT_PASSWORD"; then
    echo "  Warning: Nextcloud database backup failed, continuing..."
fi

# Backup volumes.
NEXTCLOUD_VOLUME="nextcloud-data"
if docker volume inspect "$NEXTCLOUD_VOLUME" >/dev/null 2>&1; then
    backup_volume "$NEXTCLOUD_VOLUME" "$NEXTCLOUD_BACKUP_DIR" "nextcloud-data" "$TIMESTAMP"
fi

ONLYOFFICE_VOLUME="onlyoffice-data"
if docker volume inspect "$ONLYOFFICE_VOLUME" >/dev/null 2>&1; then
    backup_volume "$ONLYOFFICE_VOLUME" "$NEXTCLOUD_BACKUP_DIR" "onlyoffice-data" "$TIMESTAMP"
fi

ONLYOFFICE_LOG_VOLUME="onlyoffice-log"
if docker volume inspect "$ONLYOFFICE_LOG_VOLUME" >/dev/null 2>&1; then
    backup_volume "$ONLYOFFICE_LOG_VOLUME" "$NEXTCLOUD_BACKUP_DIR" "onlyoffice-log" "$TIMESTAMP"
fi

# Disable maintenance mode.
if [ "$NC_MAINTENANCE_ENABLED" = true ]; then
    echo "  Disabling Nextcloud maintenance mode..."
    if docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --off > /dev/null 2>&1; then
        echo "  ✓ Maintenance mode disabled."
        NC_MAINTENANCE_ENABLED=false
    else
        echo "  Warning: Could not disable maintenance mode. Disable manually with:"
        echo "    docker exec $NC_CONTAINER php /var/www/html/occ maintenance:mode --off"
    fi
fi

echo ""
# Clean up old backups (older than 30 days).
cleanup_old_backups "$NEXTCLOUD_BACKUP_DIR" 30
echo ""
echo "Nextcloud backup completed!"
echo "Backup locations:"
echo "  - Database: ${NEXTCLOUD_BACKUP_DIR}/database/"
echo "  - Files: ${NEXTCLOUD_BACKUP_DIR}/files/"
