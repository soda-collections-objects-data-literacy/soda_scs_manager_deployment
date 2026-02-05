#!/bin/bash

# Backup script for Keycloak.
# Backs up the Keycloak database.
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
KEYCLOAK_BACKUP_DIR="${BASE_BACKUP_DIR}/keycloak"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/keycloak"
DB_CONTAINER="scs--database"
DB_ROOT_PASSWORD="${SCS_DB_ROOT_PASSWORD}"
KC_DB_NAME="${KC_DB_NAME:-keycloak}"

# Create backup directories.
mkdir -p "$KEYCLOAK_BACKUP_DIR"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

echo "=========================================="
echo "Backing up Keycloak"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $KEYCLOAK_BACKUP_DIR"
echo ""

if [ -z "$KC_DB_NAME" ]; then
    echo "  Error: KC_DB_NAME is empty after default assignment."
    exit 1
fi

if backup_database "$KC_DB_NAME" "$KEYCLOAK_BACKUP_DIR" "keycloak-db" "$TIMESTAMP" "$DB_CONTAINER" "$DB_ROOT_PASSWORD"; then
    echo ""
    # Clean up old backups (older than 30 days).
    cleanup_old_backups "$KEYCLOAK_BACKUP_DIR" 30
    echo ""
    echo "Keycloak backup completed!"
    echo "Backup location: ${KEYCLOAK_BACKUP_DIR}/database/"
else
    echo ""
    echo "Error: Keycloak database backup failed."
    exit 1
fi
