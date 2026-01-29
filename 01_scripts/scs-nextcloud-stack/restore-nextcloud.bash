#!/bin/bash

# Restore Nextcloud from backup.
# Restores database and nextcloud-data volume from timestamped backup files.
# Run from repo root.
#
# WARNING: This will overwrite existing Nextcloud data!

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
BACKUP_DIR="/srv/backups/nextcloud"
DB_CONTAINER="scs--database"
NC_CONTAINER="nextcloud--nextcloud"
DB_NAME="${NEXTCLOUD_DB_NAME}"
DB_ROOT_PASSWORD="${SCS_DB_ROOT_PASSWORD}"

# Volume name (as defined in scs-nextcloud-stack/docker-compose.yml).
NEXTCLOUD_VOLUME="nextcloud-data"

echo "=========================================="
echo "Nextcloud Restore"
echo "=========================================="
echo ""

# Check if backup directory exists.
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not found: $BACKUP_DIR"
    echo "Run backup-nextcloud.bash first to create backups."
    exit 1
fi

# List available backups.
echo "Available database backups:"
DB_BACKUPS=($(ls -1t "$BACKUP_DIR"/nextcloud-db_*.sql 2>/dev/null || true))
if [ ${#DB_BACKUPS[@]} -eq 0 ]; then
    echo "  No database backups found."
    exit 1
fi

for i in "${!DB_BACKUPS[@]}"; do
    BACKUP_FILE=$(basename "${DB_BACKUPS[$i]}")
    BACKUP_SIZE=$(du -h "${DB_BACKUPS[$i]}" | cut -f1)
    echo "  [$i] $BACKUP_FILE (${BACKUP_SIZE})"
done
echo ""

read -p "Enter backup number to restore (or 'q' to quit): " BACKUP_CHOICE

if [[ "$BACKUP_CHOICE" == "q" ]]; then
    echo "Restore cancelled."
    exit 0
fi

if ! [[ "$BACKUP_CHOICE" =~ ^[0-9]+$ ]] || [ "$BACKUP_CHOICE" -ge ${#DB_BACKUPS[@]} ]; then
    echo "Error: Invalid backup number."
    exit 1
fi

DB_BACKUP_FILE="${DB_BACKUPS[$BACKUP_CHOICE]}"
TIMESTAMP=$(basename "$DB_BACKUP_FILE" | sed 's/nextcloud-db_\(.*\)\.sql/\1/')
DATA_BACKUP_FILE="${BACKUP_DIR}/nextcloud-data_${TIMESTAMP}.tar.gz"

echo ""
echo "Selected backup:"
echo "  Database: $(basename "$DB_BACKUP_FILE")"
if [ -f "$DATA_BACKUP_FILE" ]; then
    echo "  Data volume: $(basename "$DATA_BACKUP_FILE")"
else
    echo "  Data volume: NOT FOUND (will not restore data volume)"
fi
echo ""
echo "WARNING: This will:"
echo "  1. Stop Nextcloud services."
echo "  2. Drop and recreate the Nextcloud database."
echo "  3. Restore database from backup."
if [ -f "$DATA_BACKUP_FILE" ]; then
    echo "  4. Delete and restore nextcloud-data volume."
fi
echo ""
read -p "Are you sure you want to proceed? Type 'YES' to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "=========================================="
echo "Starting restore process..."
echo "=========================================="
echo ""

# 1. Stop Nextcloud services.
echo "Step 1: Stopping Nextcloud services..."
docker compose stop nextcloud--nextcloud nextcloud--nextcloud-reverse-proxy nextcloud--onlyoffice-document-server nextcloud--onlyoffice-reverse-proxy
echo "✓ Services stopped."
echo ""

# 2. Drop and recreate database.
echo "Step 2: Dropping and recreating database..."
docker exec "$DB_CONTAINER" mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null
docker exec "$DB_CONTAINER" mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE ${DB_NAME};" 2>/dev/null
echo "✓ Database recreated."
echo ""

# 3. Restore database.
echo "Step 3: Restoring database..."
if docker exec -i "$DB_CONTAINER" mariadb -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" < "$DB_BACKUP_FILE" 2>/dev/null; then
    echo "✓ Database restored."
else
    echo "Error: Database restore failed."
    exit 1
fi
echo ""

# 4. Restore data volume if backup exists.
if [ -f "$DATA_BACKUP_FILE" ]; then
    echo "Step 4: Restoring nextcloud-data volume..."
    echo "This may take a long time depending on data size..."

    # Remove old volume content and restore.
    if docker run --rm \
        -v "${NEXTCLOUD_VOLUME}:/target" \
        -v "${BACKUP_DIR}:/backup:ro" \
        alpine:latest \
        sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null || true; tar xzf /backup/nextcloud-data_${TIMESTAMP}.tar.gz -C /target" 2>/dev/null; then
        echo "✓ Nextcloud data volume restored."
    else
        echo "Error: Data volume restore failed."
        exit 1
    fi
    echo ""
fi

# 5. Start services.
echo "Step 5: Starting Nextcloud services..."
docker compose up -d nextcloud--nextcloud nextcloud--nextcloud-reverse-proxy nextcloud--onlyoffice-document-server nextcloud--onlyoffice-reverse-proxy
echo "✓ Services started."
echo ""

# 6. Disable maintenance mode (in case it was enabled in backup).
echo "Step 6: Ensuring maintenance mode is off..."
sleep 5  # Give container time to start.
docker exec "$NC_CONTAINER" php /var/www/html/occ maintenance:mode --off > /dev/null 2>&1 || true
echo "✓ Maintenance mode disabled."
echo ""

echo "=========================================="
echo "Restore completed successfully!"
echo "=========================================="
echo ""
echo "Restored from:"
echo "  Database: $(basename "$DB_BACKUP_FILE")"
if [ -f "$DATA_BACKUP_FILE" ]; then
    echo "  Data: $(basename "$DATA_BACKUP_FILE")"
fi
echo ""
echo "Verify Nextcloud is working:"
echo "  - Check the web interface."
echo "  - Test file access and uploads."
echo "  - Check background jobs in admin settings."
