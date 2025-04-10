#!/bin/bash
export $(cat .env) > /dev/null 2>&1;

# Check if snapshot dir exists
if [ ! -d "/var/snapshots" ]; then
    echo "Snapshot directory does not exist. Creating..."
    mkdir -p /var/snapshots
fi

# Check if snapshot dir is writable by www-data
if sudo -u www-data [ ! -w "/var/snapshots" ]; then
    echo "Snapshot directory is not writable by www-data. Fixing permissions..."
    sudo chown www-data:www-data /var/snapshots
    sudo chmod 755 /var/snapshots
    if sudo -u www-data [ ! -w "/var/snapshots" ]; then
        echo "Failed to make snapshot directory writable by www-data. Please check permissions."
        exit 1
    fi
fi

docker compose up -d
