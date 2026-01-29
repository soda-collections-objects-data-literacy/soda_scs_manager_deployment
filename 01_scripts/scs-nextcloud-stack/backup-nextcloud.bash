#!/bin/bash

# Backup Nextcloud database and volumes.
# Creates timestamped backups in the backups directory.
# Run from repo root.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$ROOT_DIR"

# Load environment variables.
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "Error: .env file not found in repo root."
    exit 1
fi

# Check required env vars.
if [ -z "${SCS_DB_ROOT_PASSWORD}" ]; then
    echo "Error: SCS_DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${NEXTCLOUD_DB_NAME}" ]; then
    echo "Error: NEXTCLOUD_DB_NAME environment variable is not set."
    exit 1
fi

# Configuration.
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/srv/backups/nextcloud"
DB_CONTAINER="scs--database"
NC_CONTAINER="nextcloud--nextcloud"
DB_NAME="${NEXTCLOUD_DB_NAME}"
DB_ROOT_PASSWORD="${SCS_DB_ROOT_PASSWORD}"

# Volume names (as defined in scs-nextcloud-stack/docker-compose.yml).
NEXTCLOUD_VOLUME="nextcloud-data"
ONLYOFFICE_VOLUME="onlyoffice-data"

# Create backup directory.
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "Nextcloud Backup"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $BACKUP_DIR"
echo ""

# 1. Enable maintenance mode.
echo "Step 1: Enabling Nextcloud maintenance mode..."
if docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --on > /dev/null 2>&1; then
    echo "✓ Maintenance mode enabled."
    MAINTENANCE_WAS_ENABLED=true
else
    echo "Warning: Could not enable maintenance mode. Continuing anyway."
    MAINTENANCE_WAS_ENABLED=false
fi
echo ""

# 2. Backup database.
echo "Step 2: Backing up database ($DB_NAME)..."
DB_BACKUP_FILE="${BACKUP_DIR}/nextcloud-db_${TIMESTAMP}.sql"
if docker exec "$DB_CONTAINER" mariadb-dump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "$DB_BACKUP_FILE" 2>/dev/null; then
    DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
    echo "✓ Database backed up to: $DB_BACKUP_FILE (${DB_SIZE})"
else
    echo "Error: Database backup failed."
    # Try to disable maintenance mode before exiting.
    if [ "$MAINTENANCE_WAS_ENABLED" = true ]; then
        docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --off > /dev/null 2>&1 || true
    fi
    exit 1
fi
echo ""

# 3. Backup nextcloud-data volume.
echo "Step 3: Backing up nextcloud-data volume..."
NEXTCLOUD_DATA_BACKUP="${BACKUP_DIR}/nextcloud-data_${TIMESTAMP}.tar.gz"
echo "This may take a long time depending on data size..."

if docker run --rm \
    -v "${NEXTCLOUD_VOLUME}:/source:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine:latest \
    tar czf "/backup/nextcloud-data_${TIMESTAMP}.tar.gz" -C /source . 2>/dev/null; then
    VOLUME_SIZE=$(du -h "$NEXTCLOUD_DATA_BACKUP" | cut -f1)
    echo "✓ Nextcloud data backed up to: $NEXTCLOUD_DATA_BACKUP (${VOLUME_SIZE})"
else
    echo "Error: Nextcloud data volume backup failed."
    # Try to disable maintenance mode before exiting.
    if [ "$MAINTENANCE_WAS_ENABLED" = true ]; then
        docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --off > /dev/null 2>&1 || true
    fi
    exit 1
fi
echo ""

# 4. Optionally backup onlyoffice-data volume.
read -p "Backup OnlyOffice data volume? (y/N): " BACKUP_ONLYOFFICE
if [[ "$BACKUP_ONLYOFFICE" =~ ^[Yy]$ ]]; then
    echo "Step 4: Backing up onlyoffice-data volume..."
    ONLYOFFICE_DATA_BACKUP="${BACKUP_DIR}/onlyoffice-data_${TIMESTAMP}.tar.gz"

    if docker run --rm \
        -v "${ONLYOFFICE_VOLUME}:/source:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine:latest \
        tar czf "/backup/onlyoffice-data_${TIMESTAMP}.tar.gz" -C /source . 2>/dev/null; then
        ONLYOFFICE_SIZE=$(du -h "$ONLYOFFICE_DATA_BACKUP" | cut -f1)
        echo "✓ OnlyOffice data backed up to: $ONLYOFFICE_DATA_BACKUP (${ONLYOFFICE_SIZE})"
    else
        echo "Warning: OnlyOffice data volume backup failed."
    fi
    echo ""
else
    echo "Skipping OnlyOffice data backup."
    echo ""
fi

# 5. Disable maintenance mode.
if [ "$MAINTENANCE_WAS_ENABLED" = true ]; then
    echo "Step 5: Disabling Nextcloud maintenance mode..."
    if docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --off > /dev/null 2>&1; then
        echo "✓ Maintenance mode disabled."
    else
        echo "Warning: Could not disable maintenance mode. Disable manually with:"
        echo "  docker exec $NC_CONTAINER php /var/www/html/occ maintenance:mode --off"
    fi
    echo ""
fi

# Summary.
echo "=========================================="
echo "Backup completed successfully!"
echo "=========================================="
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Files created:"
ls -lh "$BACKUP_DIR" | grep "$TIMESTAMP" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "To restore from this backup, see: docs/maintenance/updates.md (Rollback section)"
echo ""
echo "Consider moving backups to secure off-site storage."
