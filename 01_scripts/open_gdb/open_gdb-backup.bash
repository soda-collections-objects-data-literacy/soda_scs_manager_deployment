#!/bin/bash

# Backup script for Open_GDB (RDF4J).
# Backs up RDF4J and authproxy volumes.
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
OPENGDB_BACKUP_DIR="${BASE_BACKUP_DIR}/open_gdb"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/open_gdb"

# Create backup directories.
mkdir -p "$OPENGDB_BACKUP_DIR"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

echo "=========================================="
echo "Backing up Open_GDB (RDF4J)"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $OPENGDB_BACKUP_DIR"
echo ""

# Backup rdf4j-data volume.
RDF4J_VOLUME="soda_scs_manager_deployment_rdf4j-data"
if docker volume inspect "$RDF4J_VOLUME" >/dev/null 2>&1; then
    backup_volume "$RDF4J_VOLUME" "$OPENGDB_BACKUP_DIR" "rdf4j-data" "$TIMESTAMP"
fi

# Backup rdf4j-logs volume.
RDF4J_LOGS_VOLUME="soda_scs_manager_deployment_rdf4j-logs"
if docker volume inspect "$RDF4J_LOGS_VOLUME" >/dev/null 2>&1; then
    backup_volume "$RDF4J_LOGS_VOLUME" "$OPENGDB_BACKUP_DIR" "rdf4j-logs" "$TIMESTAMP"
fi

# Backup authproxy-data volume.
AUTHPROXY_VOLUME="soda_scs_manager_deployment_authproxy-data"
if docker volume inspect "$AUTHPROXY_VOLUME" >/dev/null 2>&1; then
    backup_volume "$AUTHPROXY_VOLUME" "$OPENGDB_BACKUP_DIR" "authproxy-data" "$TIMESTAMP"
fi

echo ""
# Clean up old backups (older than 30 days).
cleanup_old_backups "$OPENGDB_BACKUP_DIR" 30
echo ""
echo "Open_GDB backup completed!"
echo "Backup location: ${OPENGDB_BACKUP_DIR}/files/"
