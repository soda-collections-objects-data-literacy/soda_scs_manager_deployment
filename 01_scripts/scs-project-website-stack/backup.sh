#!/bin/bash

# Backup script for SCS Project Website.
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

if [ -z "${PROJECT_WEBSITE_DB_NAME:-}" ]; then
    echo "Error: PROJECT_WEBSITE_DB_NAME environment variable is not set."
    exit 1
fi

if [ -z "${PROJECT_WEBSITE_DB_USER:-}" ]; then
    echo "Error: PROJECT_WEBSITE_DB_USER environment variable is not set."
    exit 1
fi

if [ -z "${PROJECT_WEBSITE_DB_PASSWORD:-}" ]; then
    echo "Error: PROJECT_WEBSITE_DB_PASSWORD environment variable is not set."
    exit 1
fi

# Configuration.
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_BACKUP_DIR="/srv/backups"
PROJECT_WEBSITE_BACKUP_DIR="${BASE_BACKUP_DIR}/scs-project-website"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/scs-project-website"
DB_CONTAINER="scs--database"
PROJECT_WEBSITE_CONTAINER="scs-project-website--drupal"

# Create backup directories.
mkdir -p "${PROJECT_WEBSITE_BACKUP_DIR}/database"
mkdir -p "${PROJECT_WEBSITE_BACKUP_DIR}/files"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

# Initialize maintenance mode flag.
PROJECT_WEBSITE_MAINTENANCE_ENABLED=false

# Trap handler to ensure maintenance mode is disabled on exit.
cleanup_maintenance_mode() {
    if [ "$PROJECT_WEBSITE_MAINTENANCE_ENABLED" = true ]; then
        echo ""
        echo "Cleaning up: Disabling Project Website maintenance mode..."
        docker exec "$PROJECT_WEBSITE_CONTAINER" drush state:set system.maintenance_mode 0 > /dev/null 2>&1 || true
    fi
}
trap cleanup_maintenance_mode EXIT

echo "=========================================="
echo "Backing up SCS Project Website"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $PROJECT_WEBSITE_BACKUP_DIR"
echo ""

# Enable maintenance mode.
if docker ps --format "{{.Names}}" | grep -q "^${PROJECT_WEBSITE_CONTAINER}$"; then
    echo "  Enabling Project Website maintenance mode..."
    if docker exec "$PROJECT_WEBSITE_CONTAINER" drush state:set system.maintenance_mode 1 > /dev/null 2>&1; then
        echo "  ✓ Maintenance mode enabled."
        PROJECT_WEBSITE_MAINTENANCE_ENABLED=true
    else
        echo "  Warning: Could not enable maintenance mode. Continuing anyway."
        PROJECT_WEBSITE_MAINTENANCE_ENABLED=false
    fi
else
    echo "  Warning: Project Website container not running. Skipping maintenance mode."
    PROJECT_WEBSITE_MAINTENANCE_ENABLED=false
fi

# Backup database.
echo "  Backing up database: ${PROJECT_WEBSITE_DB_NAME}..."
DB_BACKUP_FILE="${PROJECT_WEBSITE_BACKUP_DIR}/database/project-website-db_${TIMESTAMP}.sql"
# Database backup is created by shell redirect, so it's already owned by current user.
if docker exec "$DB_CONTAINER" mariadb-dump -u"${PROJECT_WEBSITE_DB_USER}" -p"${PROJECT_WEBSITE_DB_PASSWORD}" "${PROJECT_WEBSITE_DB_NAME}" > "$DB_BACKUP_FILE" 2>/dev/null; then
    # Set permissions.
    if [ -f "$DB_BACKUP_FILE" ]; then
        chmod 644 "$DB_BACKUP_FILE" 2>/dev/null || true
    fi
    DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
    echo "  ✓ Database backed up: $DB_BACKUP_FILE (${DB_SIZE})"
else
    echo "  ✗ Error: Database backup failed."
    exit 1
fi

# Backup volumes (drupal-root from scs-project-website-stack/volumes).
PROJECT_WEBSITE_VOLUMES_DIR="${ROOT_DIR}/scs-project-website-stack/volumes"
if [ -d "$PROJECT_WEBSITE_VOLUMES_DIR" ]; then
    echo "  Backing up volumes directory..."
    VOLUMES_BACKUP_FILE="${PROJECT_WEBSITE_BACKUP_DIR}/files/project-website-volumes_${TIMESTAMP}.tar.gz"
    # Tar backup is created with current user ownership.
    if tar -czf "$VOLUMES_BACKUP_FILE" -C "$PROJECT_WEBSITE_VOLUMES_DIR" drupal-root 2>/dev/null; then
        # Set permissions.
        if [ -f "$VOLUMES_BACKUP_FILE" ]; then
            chmod 644 "$VOLUMES_BACKUP_FILE" 2>/dev/null || true
        fi
        VOLUMES_SIZE=$(du -h "$VOLUMES_BACKUP_FILE" | cut -f1)
        echo "  ✓ Volumes backed up: $VOLUMES_BACKUP_FILE (${VOLUMES_SIZE})"
    else
        echo "  ✗ Error: Volumes backup failed."
    fi
else
    echo "  Warning: Volumes directory not found at $PROJECT_WEBSITE_VOLUMES_DIR"
fi

# Disable maintenance mode.
if [ "$PROJECT_WEBSITE_MAINTENANCE_ENABLED" = true ]; then
    echo "  Disabling Project Website maintenance mode..."
    if docker exec "$PROJECT_WEBSITE_CONTAINER" drush state:set system.maintenance_mode 0 > /dev/null 2>&1; then
        echo "  ✓ Maintenance mode disabled."
        PROJECT_WEBSITE_MAINTENANCE_ENABLED=false
    else
        echo "  Warning: Could not disable maintenance mode. Disable manually with:"
        echo "    docker exec $PROJECT_WEBSITE_CONTAINER drush state:set system.maintenance_mode 0"
    fi
fi

echo ""
# Clean up old backups (older than 30 days).
cleanup_old_backups "$PROJECT_WEBSITE_BACKUP_DIR" 30
echo ""
echo "SCS Project Website backup completed!"
echo "Backup locations:"
echo "  - Database: ${PROJECT_WEBSITE_BACKUP_DIR}/database/"
echo "  - Files: ${PROJECT_WEBSITE_BACKUP_DIR}/files/"
