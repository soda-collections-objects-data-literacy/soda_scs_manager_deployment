#!/bin/bash

# Global backup script that triggers all service-specific backup scripts.
# Backs up databases and volumes for:
# - JupyterHub (including client containers)
# - Keycloak
# - Open_GDB (RDF4J)
# - SCS-Manager
# - Nextcloud
# - WebProtege
# - SCS Project Website
#
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
else
    echo "Error: .env file not found in repo root."
    exit 1
fi

# Configuration.
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_BACKUP_DIR="/srv/backups"

# Validate critical variables.
if [ -z "$TIMESTAMP" ]; then
    echo "Error: Failed to generate timestamp."
    exit 1
fi

if [ -z "$BASE_BACKUP_DIR" ]; then
    echo "Error: BASE_BACKUP_DIR is empty."
    exit 1
fi

# Create backup directories.
mkdir -p "${BASE_BACKUP_DIR}"

echo "=========================================="
echo "SCS Services Backup"
echo "=========================================="
echo "Timestamp: $TIMESTAMP"
echo "Backup base directory: $BASE_BACKUP_DIR"
echo ""

# Track backup results.
BACKUP_FAILURES=0
BACKUP_SUCCESSES=0

# Function to run a backup script and track results.
run_backup() {
    local serviceName=$1
    local backupScript=$2
    
    echo ""
    echo "=========================================="
    echo "Running backup for: $serviceName"
    echo "=========================================="
    
    if [ ! -f "$backupScript" ]; then
        echo "  ✗ Error: Backup script not found: $backupScript"
        BACKUP_FAILURES=$((BACKUP_FAILURES + 1))
        return 1
    fi
    
    if [ ! -x "$backupScript" ]; then
        echo "  ✗ Error: Backup script is not executable: $backupScript"
        BACKUP_FAILURES=$((BACKUP_FAILURES + 1))
        return 1
    fi
    
    if bash "$backupScript"; then
        echo "  ✓ $serviceName backup completed successfully."
        BACKUP_SUCCESSES=$((BACKUP_SUCCESSES + 1))
        return 0
    else
        echo "  ✗ $serviceName backup failed."
        BACKUP_FAILURES=$((BACKUP_FAILURES + 1))
        return 1
    fi
}

# Run backups for each service.
run_backup "JupyterHub" "${SCRIPT_DIR}/../jupyterhub/jupyterhub-backup.bash"
run_backup "Keycloak" "${SCRIPT_DIR}/../keycloak/keycloak-backup.bash"
run_backup "Open_GDB" "${SCRIPT_DIR}/../open_gdb/open_gdb-backup.bash"
run_backup "SCS-Manager" "${SCRIPT_DIR}/../scs-manager-stack/scs-manager-backup.bash"
run_backup "Nextcloud" "${SCRIPT_DIR}/../scs-nextcloud-stack/nextcloud-backup.bash"
run_backup "WebProtege" "${SCRIPT_DIR}/../webprotege/webprotege-backup.bash"
run_backup "SCS Project Website" "${SCRIPT_DIR}/../scs-project-page/scs-project-website-backup.bash"

# Summary.
echo ""
echo "=========================================="
echo "Backup Summary"
echo "=========================================="
echo ""
echo "Backup timestamp: $TIMESTAMP"
echo "Backup base directory: $BASE_BACKUP_DIR"
echo ""
echo "Results:"
echo "  - Successful backups: $BACKUP_SUCCESSES"
echo "  - Failed backups: $BACKUP_FAILURES"
echo ""
echo "Backup locations (organized by service and type):"
echo "  - JupyterHub: ${BASE_BACKUP_DIR}/jupyterhub/"
echo "  - Keycloak: ${BASE_BACKUP_DIR}/keycloak/"
echo "  - Open_GDB: ${BASE_BACKUP_DIR}/open_gdb/"
echo "  - SCS-Manager: ${BASE_BACKUP_DIR}/scs-manager/"
echo "  - Nextcloud: ${BASE_BACKUP_DIR}/nextcloud/"
echo "  - WebProtege: ${BASE_BACKUP_DIR}/webprotege/"
echo "  - SCS Project Website: ${BASE_BACKUP_DIR}/scs-project-website/"
echo ""

# List files created with this timestamp.
echo "Files created (with timestamp $TIMESTAMP):"
for serviceDir in "${BASE_BACKUP_DIR}/jupyterhub" "${BASE_BACKUP_DIR}/keycloak" \
                  "${BASE_BACKUP_DIR}/open_gdb" "${BASE_BACKUP_DIR}/scs-manager" \
                  "${BASE_BACKUP_DIR}/nextcloud" "${BASE_BACKUP_DIR}/webprotege" \
                  "${BASE_BACKUP_DIR}/scs-project-website"; do
    if [ -d "$serviceDir" ]; then
        for typeDir in "${serviceDir}/database" "${serviceDir}/files"; do
            if [ -d "$typeDir" ]; then
                ls -lh "$typeDir" | grep "$TIMESTAMP" | awk '{print "  " $9 " (" $5 ")"}' || true
            fi
        done
    fi
done
echo ""

# Function to clean up backups older than one month.
cleanup_old_backups() {
    local retentionDays=30
    local deletedCount=0
    local freedSpace=0
    
    echo "=========================================="
    echo "Cleaning up backups older than $retentionDays days"
    echo "=========================================="
    echo ""
    
    # Find and delete old backup files in all service directories.
    for serviceDir in "${BASE_BACKUP_DIR}/jupyterhub" "${BASE_BACKUP_DIR}/keycloak" \
                      "${BASE_BACKUP_DIR}/open_gdb" "${BASE_BACKUP_DIR}/scs-manager" \
                      "${BASE_BACKUP_DIR}/nextcloud" "${BASE_BACKUP_DIR}/webprotege" \
                      "${BASE_BACKUP_DIR}/scs-project-website"; do
        if [ -d "$serviceDir" ]; then
            for typeDir in "${serviceDir}/database" "${serviceDir}/files"; do
                if [ -d "$typeDir" ]; then
                    # Find files older than retentionDays and delete them.
                    while IFS= read -r -d '' oldFile; do
                        if [ -f "$oldFile" ]; then
                            fileSize=$(du -b "$oldFile" | cut -f1)
                            rm -f "$oldFile" && {
                                deletedCount=$((deletedCount + 1))
                                freedSpace=$((freedSpace + fileSize))
                                echo "  Deleted: $(basename "$oldFile")"
                            } || echo "  Warning: Failed to delete: $oldFile"
                        fi
                    done < <(find "$typeDir" -type f -mtime +${retentionDays} -print0 2>/dev/null)
                fi
            done
        fi
    done
    
    # Clean up empty directories in tmp.
    if [ -d "${BASE_BACKUP_DIR}/tmp" ]; then
        find "${BASE_BACKUP_DIR}/tmp" -type d -empty -delete 2>/dev/null || true
    fi
    
    echo ""
    if [ $deletedCount -gt 0 ]; then
        freedSpaceMB=$((freedSpace / 1024 / 1024))
        echo "✓ Cleanup completed:"
        echo "  - Files deleted: $deletedCount"
        echo "  - Space freed: ${freedSpaceMB} MB"
    else
        echo "✓ No old backups found to delete."
    fi
    echo ""
}

# Clean up old backups.
cleanup_old_backups

if [ $BACKUP_FAILURES -eq 0 ]; then
    echo "✓ All backups completed successfully!"
    echo ""
    echo "Consider moving backups to secure off-site storage."
    exit 0
else
    echo "⚠ Some backups failed. Please review the output above."
    echo ""
    echo "Consider moving successful backups to secure off-site storage."
    exit 1
fi
