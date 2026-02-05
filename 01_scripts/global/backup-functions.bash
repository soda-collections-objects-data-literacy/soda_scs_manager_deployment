#!/bin/bash

# Common backup functions used by all service backup scripts.
# Source this file in service-specific backup scripts.

# Function to clean up old backup files (older than retentionDays).
cleanup_old_backups() {
    local backupDir=$1
    local retentionDays=${2:-30}
    local deletedCount=0
    local freedSpace=0
    
    if [ ! -d "$backupDir" ]; then
        return 0
    fi
    
    # Find and delete old backup files.
    while IFS= read -r -d '' oldFile; do
        if [ -f "$oldFile" ]; then
            fileSize=$(du -b "$oldFile" | cut -f1)
            rm -f "$oldFile" && {
                deletedCount=$((deletedCount + 1))
                freedSpace=$((freedSpace + fileSize))
            } || true
        fi
    done < <(find "$backupDir" -type f -mtime +${retentionDays} -print0 2>/dev/null)
    
    # Clean up empty directories.
    find "$backupDir" -type d -empty -delete 2>/dev/null || true
    
    if [ $deletedCount -gt 0 ]; then
        freedSpaceMB=$((freedSpace / 1024 / 1024))
        echo "  Cleaned up $deletedCount old backup file(s), freed ${freedSpaceMB} MB"
    fi
}

# Function to backup a volume.
backup_volume() {
    local volumeName=$1
    local backupDir=$2
    local backupName=$3
    local timestamp=$4
    
    # Validate parameters.
    if [ -z "$volumeName" ] || [ -z "$backupDir" ] || [ -z "$backupName" ] || [ -z "$timestamp" ]; then
        echo "  ✗ Error: backup_volume called with empty parameter(s)"
        return 1
    fi
    
    # Skip shared volumes (they are backed up separately).
    if [[ "$volumeName" =~ (shared|shared-data|shared_data|scs--shared-data) ]]; then
        echo "  ⊘ Skipping shared volume: $volumeName (backed up separately)"
        return 0
    fi
    
    echo "  Backing up volume: $volumeName..."
    local filesDir="${backupDir}/files"
    mkdir -p "$filesDir"
    local backupFile="${filesDir}/${backupName}_${timestamp}.tar.gz"
    
    # Get current user ID and group ID.
    CURRENT_UID=$(id -u)
    CURRENT_GID=$(id -g)
    
    # Run Docker as root (needed to read volumes), then fix ownership afterward.
    if docker run --rm \
        -v "${volumeName}:/source:ro" \
        -v "${filesDir}:/backup" \
        alpine:latest \
        tar czf "/backup/${backupName}_${timestamp}.tar.gz" -C /source . 2>/dev/null; then
        # Fix ownership and permissions.
        if [ -f "$backupFile" ]; then
            # If running as non-root user, use sudo to change ownership.
            if [ "$CURRENT_UID" != "0" ]; then
                sudo chown "${CURRENT_UID}:${CURRENT_GID}" "$backupFile" 2>/dev/null || {
                    echo "  Warning: Failed to change ownership (needs sudo access)"
                }
            fi
            chmod 644 "$backupFile" 2>/dev/null || sudo chmod 644 "$backupFile" 2>/dev/null || true
        fi
        local size=$(du -h "$backupFile" | cut -f1)
        echo "  ✓ Volume backed up: $backupFile (${size})"
        return 0
    else
        echo "  ✗ Error: Volume backup failed for $volumeName"
        return 1
    fi
}

# Function to backup a database.
backup_database() {
    local dbName=$1
    local backupDir=$2
    local backupName=$3
    local timestamp=$4
    local dbContainer=$5
    local dbRootPassword=$6
    
    # Validate parameters.
    if [ -z "$dbName" ] || [ -z "$backupDir" ] || [ -z "$backupName" ] || [ -z "$timestamp" ] || [ -z "$dbContainer" ] || [ -z "$dbRootPassword" ]; then
        echo "  ✗ Error: backup_database called with empty parameter(s)"
        return 1
    fi
    
    echo "  Backing up database: $dbName..."
    local databaseDir="${backupDir}/database"
    mkdir -p "$databaseDir"
    local backupFile="${databaseDir}/${backupName}_${timestamp}.sql"
    
    # Database backup is created by shell redirect, so it's already owned by current user.
    # No need to change ownership.
    if docker exec "$dbContainer" mariadb-dump -u root -p"${dbRootPassword}" "${dbName}" > "$backupFile" 2>/dev/null; then
        # Set permissions.
        if [ -f "$backupFile" ]; then
            chmod 644 "$backupFile" 2>/dev/null || true
        fi
        local size=$(du -h "$backupFile" | cut -f1)
        echo "  ✓ Database backed up: $backupFile (${size})"
        return 0
    else
        echo "  ✗ Error: Database backup failed for $dbName"
        return 1
    fi
}

# Function to backup MongoDB database.
backup_mongodb() {
    local containerName=$1
    local backupDir=$2
    local backupName=$3
    local timestamp=$4
    
    # Validate parameters.
    if [ -z "$containerName" ] || [ -z "$backupDir" ] || [ -z "$backupName" ] || [ -z "$timestamp" ]; then
        echo "  ✗ Error: backup_mongodb called with empty parameter(s)"
        return 1
    fi
    
    echo "  Backing up MongoDB from container: $containerName..."
    local databaseDir="${backupDir}/database"
    mkdir -p "$databaseDir"
    local backupFile="${databaseDir}/${backupName}_${timestamp}.archive"
    
    # MongoDB backup is created by shell redirect, so it's already owned by current user.
    # No need to change ownership.
    if docker exec "$containerName" mongodump --archive > "$backupFile" 2>/dev/null; then
        # Set permissions.
        if [ -f "$backupFile" ]; then
            chmod 644 "$backupFile" 2>/dev/null || true
        fi
        local size=$(du -h "$backupFile" | cut -f1)
        echo "  ✓ MongoDB backed up: $backupFile (${size})"
        return 0
    else
        echo "  ✗ Error: MongoDB backup failed for $containerName"
        return 1
    fi
}
