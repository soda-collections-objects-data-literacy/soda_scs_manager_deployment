#!/bin/bash
export $(cat .env) > /dev/null 2>&1;

# Check if snapshot dir exists
if [ ! -d "/var/snapshots" ]; then
    echo "Snapshot directory does not exist. Creating..."
    sudo mkdir -p /var/scs-manager/snapshots
fi

# Check if snapshot dir is writable by www-data
if sudo -u www-data [ ! -w "/var/scs-manager/snapshots" ]; then
    echo "Snapshot directory is not writable by www-data. Fixing permissions..."
    sudo chown -R www-data:www-data /var/scs-manager/snapshots
    sudo chmod -R 775 /var/scs-manager/snapshots
    if sudo -u www-data [ ! -w "/var/scs-manager/snapshots" ]; then
        echo "Failed to make snapshot directory writable by www-data. Please check permissions."
        exit 1
    fi
fi

docker compose up -d
