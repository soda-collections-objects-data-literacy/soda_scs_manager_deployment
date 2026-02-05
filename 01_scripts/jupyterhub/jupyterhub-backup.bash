#!/bin/bash

# Backup script for JupyterHub.
# Backs up volumes including user volumes.
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
JUPYTERHUB_BACKUP_DIR="${BASE_BACKUP_DIR}/jupyterhub"
TMP_BASE_DIR="${BASE_BACKUP_DIR}/tmp/jupyterhub"

# Create backup directories.
mkdir -p "${JUPYTERHUB_BACKUP_DIR}/files"
mkdir -p "${TMP_BASE_DIR}"
# Ensure temp directory is writable and removable by the current user.
chmod 777 "${TMP_BASE_DIR}" 2>/dev/null || true

echo "=========================================="
echo "Backing up JupyterHub"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $JUPYTERHUB_BACKUP_DIR"
echo ""

# Backup jupyterhub-group-map volume.
if docker volume inspect jupyterhub-group-map >/dev/null 2>&1; then
    backup_volume "jupyterhub-group-map" "$JUPYTERHUB_BACKUP_DIR" "jupyterhub-group-map" "$TIMESTAMP"
fi

# Backup all jupyterhub-user-* volumes.
echo "  Finding JupyterHub user volumes..."
USER_VOLUMES=$(docker volume ls --format "{{.Name}}" | grep "^jupyterhub-user-" || true)
if [ -n "$USER_VOLUMES" ]; then
    USER_COUNT=$(echo "$USER_VOLUMES" | wc -l)
    echo "  Found $USER_COUNT user volume(s)."
    
    # Create a combined backup of all user volumes.
    FILES_DIR="${JUPYTERHUB_BACKUP_DIR}/files"
    USER_BACKUP_FILE="${FILES_DIR}/jupyterhub-user-volumes_${TIMESTAMP}.tar.gz"
    TMP_USER_DIR=$(mktemp -d -p "${TMP_BASE_DIR}" jupyterhub-user-volumes.XXXXXXXXXX)
    
    # Ensure temp directory is world-writable so Docker (running as root) and cleanup can work.
    chmod 777 "$TMP_USER_DIR" 2>/dev/null || true
    
    # Trap to ensure cleanup happens even on error.
    cleanup_temp_dir() {
        if [ -n "${TMP_USER_DIR:-}" ] && [ -d "$TMP_USER_DIR" ]; then
            # Make everything world-writable so it can be removed by any user.
            chmod -R 777 "$TMP_USER_DIR" 2>/dev/null || true
            # Try to remove the directory.
            rm -rf "$TMP_USER_DIR" 2>/dev/null || true
            # If still exists and we have sudo, try with sudo.
            if [ -d "$TMP_USER_DIR" ] && command -v sudo >/dev/null 2>&1; then
                sudo rm -rf "$TMP_USER_DIR" 2>/dev/null || true
            fi
        fi
    }
    trap cleanup_temp_dir EXIT
    
    for volume in $USER_VOLUMES; do
        echo "    Backing up $volume..."
        docker run --rm \
            -v "${volume}:/source:ro" \
            -v "${TMP_USER_DIR}:/backup" \
            alpine:latest \
            sh -c "mkdir -p /backup/volumes && tar czf /backup/volumes/${volume}.tar.gz -C /source ." 2>/dev/null || true
    done
    
    # Fix permissions after Docker creates files (Docker runs as root).
    # Make everything world-writable so cleanup can remove it.
    chmod -R 777 "$TMP_USER_DIR" 2>/dev/null || true
    
    # Create final archive (tar creates file with current user ownership).
    tar czf "$USER_BACKUP_FILE" -C "$TMP_USER_DIR" volumes/ 2>/dev/null && {
        # Set permissions.
        if [ -f "$USER_BACKUP_FILE" ]; then
            chmod 644 "$USER_BACKUP_FILE" 2>/dev/null || true
        fi
        size=$(du -h "$USER_BACKUP_FILE" | cut -f1)
        echo "  ✓ User volumes backed up: $USER_BACKUP_FILE (${size})"
    } || echo "  ✗ Error: Failed to create user volumes archive"
    
    # Cleanup temp directory.
    cleanup_temp_dir
    trap - EXIT
else
    echo "  No user volumes found."
fi

echo ""
# Clean up old backups (older than 30 days).
cleanup_old_backups "$JUPYTERHUB_BACKUP_DIR" 30
echo ""
echo "JupyterHub backup completed!"
echo "Backup location: ${JUPYTERHUB_BACKUP_DIR}/files/"
