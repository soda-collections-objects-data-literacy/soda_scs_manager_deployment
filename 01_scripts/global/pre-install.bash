#!/bin/bash
# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if snapshot dir exists
if [ ! -d "/var/snapshots" ]; then
    echo "Snapshot directory does not exist. Creating..."
    sudo mkdir -p /var/backups/scs-manager/snapshots
fi

# Check if snapshot dir is writable by www-data
if sudo -u www-data [ ! -w "/var/backups/scs-manager/snapshots" ]; then
    echo "Snapshot directory is not writable by www-data. Fixing permissions..."
    sudo chown -R www-data:www-data /var/backups/scs-manager/snapshots
    sudo chmod -R 775 /var/backups/scs-manager/snapshots
    if sudo -u www-data [ ! -w "/var/backups/scs-manager/snapshots" ]; then
        echo "Failed to make snapshot directory writable by www-data. Please check permissions."
        exit 1
    fi
fi
