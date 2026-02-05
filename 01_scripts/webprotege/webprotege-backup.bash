#!/bin/bash

# Backup script for WebProtege.
# Backs up MongoDB database and volumes.
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

# Configuration.
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_BACKUP_DIR="/srv/backups"
WEBPROTEGE_BACKUP_DIR="${BASE_BACKUP_DIR}/webprotege"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/webprotege"
WP_MONGO_CONTAINER="webprotege-mongodb"

# Create backup directories.
mkdir -p "$WEBPROTEGE_BACKUP_DIR"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

echo "=========================================="
echo "Backing up WebProtege"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $WEBPROTEGE_BACKUP_DIR"
echo ""

# Backup MongoDB database.
if docker ps --format "{{.Names}}" | grep -q "^${WP_MONGO_CONTAINER}$"; then
    backup_mongodb "$WP_MONGO_CONTAINER" "$WEBPROTEGE_BACKUP_DIR" "webprotege-mongodb" "$TIMESTAMP"
else
    echo "  Warning: WebProtege MongoDB container not running. Skipping database backup."
fi

# Backup volumes.
MONGODB_VOLUME="mongodb-data"
if docker volume inspect "$MONGODB_VOLUME" >/dev/null 2>&1; then
    backup_volume "$MONGODB_VOLUME" "$WEBPROTEGE_BACKUP_DIR" "mongodb-data" "$TIMESTAMP"
fi

WEBPROTEGE_VOLUME="webprotege-data"
if docker volume inspect "$WEBPROTEGE_VOLUME" >/dev/null 2>&1; then
    backup_volume "$WEBPROTEGE_VOLUME" "$WEBPROTEGE_BACKUP_DIR" "webprotege-data" "$TIMESTAMP"
fi

echo ""
# Clean up old backups (older than 30 days).
cleanup_old_backups "$WEBPROTEGE_BACKUP_DIR" 30
echo ""
echo "WebProtege backup completed!"
echo "Backup locations:"
echo "  - Database: ${WEBPROTEGE_BACKUP_DIR}/database/"
echo "  - Files: ${WEBPROTEGE_BACKUP_DIR}/files/"
