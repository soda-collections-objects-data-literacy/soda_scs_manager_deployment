#!/bin/bash

# Backup script for SCS-Manager.
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
SCS_MANAGER_BACKUP_DIR="${BASE_BACKUP_DIR}/scs-manager"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/scs-manager"
DB_CONTAINER="scs--database"
DB_ROOT_PASSWORD="${SCS_DB_ROOT_PASSWORD}"
SCS_MANAGER_DB_NAME="${SCS_MANAGER_DB_NAME:-scs_manager}"
SCS_MANAGER_CONTAINER="scs-manager--drupal"

# Create backup directories.
mkdir -p "$SCS_MANAGER_BACKUP_DIR"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

# Initialize maintenance mode flag.
SCS_MANAGER_MAINTENANCE_ENABLED=false

# Trap handler to ensure maintenance mode is disabled on exit.
cleanup_maintenance_mode() {
    if [ "$SCS_MANAGER_MAINTENANCE_ENABLED" = true ]; then
        echo ""
        echo "Cleaning up: Disabling SCS-Manager maintenance mode..."
        docker exec "$SCS_MANAGER_CONTAINER" drush state:set system.maintenance_mode 0 > /dev/null 2>&1 || true
    fi
}
trap cleanup_maintenance_mode EXIT

echo "=========================================="
echo "Backing up SCS-Manager"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $SCS_MANAGER_BACKUP_DIR"
echo ""

# Enable maintenance mode.
if docker ps --format "{{.Names}}" | grep -q "^${SCS_MANAGER_CONTAINER}$"; then
    echo "  Enabling SCS-Manager maintenance mode..."
    if docker exec "$SCS_MANAGER_CONTAINER" drush state:set system.maintenance_mode 1 > /dev/null 2>&1; then
        echo "  ✓ Maintenance mode enabled."
        SCS_MANAGER_MAINTENANCE_ENABLED=true
    else
        echo "  Warning: Could not enable maintenance mode. Continuing anyway."
        SCS_MANAGER_MAINTENANCE_ENABLED=false
    fi
else
    echo "  Warning: SCS-Manager container not running. Skipping maintenance mode."
    SCS_MANAGER_MAINTENANCE_ENABLED=false
fi

# Backup database.
if [ -z "$SCS_MANAGER_DB_NAME" ]; then
    echo "  Error: SCS_MANAGER_DB_NAME is empty after default assignment."
    exit 1
fi

if ! backup_database "$SCS_MANAGER_DB_NAME" "$SCS_MANAGER_BACKUP_DIR" "scs-manager-db" "$TIMESTAMP" "$DB_CONTAINER" "$DB_ROOT_PASSWORD"; then
    echo "  Warning: SCS-Manager database backup failed, continuing..."
fi

# Backup volumes.
SCS_MANAGER_DB_VOLUME="soda_scs_manager_deployment_scs-manager---database-data"
if docker volume inspect "$SCS_MANAGER_DB_VOLUME" >/dev/null 2>&1; then
    backup_volume "$SCS_MANAGER_DB_VOLUME" "$SCS_MANAGER_BACKUP_DIR" "scs-manager-database-data" "$TIMESTAMP"
fi

SCS_MANAGER_DRUPAL_VOLUME="soda_scs_manager_deployment_scs-manager--drupal-sites"
if docker volume inspect "$SCS_MANAGER_DRUPAL_VOLUME" >/dev/null 2>&1; then
    backup_volume "$SCS_MANAGER_DRUPAL_VOLUME" "$SCS_MANAGER_BACKUP_DIR" "scs-manager-drupal-sites" "$TIMESTAMP"
fi

SCS_MANAGER_REDIS_VOLUME="soda_scs_manager_deployment_scs-manager--redis-data"
if docker volume inspect "$SCS_MANAGER_REDIS_VOLUME" >/dev/null 2>&1; then
    backup_volume "$SCS_MANAGER_REDIS_VOLUME" "$SCS_MANAGER_BACKUP_DIR" "scs-manager-redis-data" "$TIMESTAMP"
fi

# Disable maintenance mode.
if [ "$SCS_MANAGER_MAINTENANCE_ENABLED" = true ]; then
    echo "  Disabling SCS-Manager maintenance mode..."
    if docker exec "$SCS_MANAGER_CONTAINER" drush state:set system.maintenance_mode 0 > /dev/null 2>&1; then
        echo "  ✓ Maintenance mode disabled."
        SCS_MANAGER_MAINTENANCE_ENABLED=false
    else
        echo "  Warning: Could not disable maintenance mode. Disable manually with:"
        echo "    docker exec $SCS_MANAGER_CONTAINER drush state:set system.maintenance_mode 0"
    fi
fi

echo ""
# Clean up old backups (older than 30 days).
cleanup_old_backups "$SCS_MANAGER_BACKUP_DIR" 30
echo ""
echo "SCS-Manager backup completed!"
echo "Backup locations:"
echo "  - Database: ${SCS_MANAGER_BACKUP_DIR}/database/"
echo "  - Files: ${SCS_MANAGER_BACKUP_DIR}/files/"
