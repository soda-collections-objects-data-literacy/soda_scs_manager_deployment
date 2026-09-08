#!/bin/bash

set -e

# Docker DNS names from .env (naming migration).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../global/scs-container-names.bash"

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Start Nextcloud service.
echo "Starting Nextcloud service..."
docker compose up -d "${SCS_CONTAINER_NEXTCLOUD}" "${SCS_CONTAINER_ODS}" "${SCS_CONTAINER_NEXTCLOUD_EDGE}" "${SCS_CONTAINER_ODS_EDGE}" "${SCS_CONTAINER_NEXTCLOUD_REDIS}"
echo "Nextcloud service started successfully."

echo "Nextcloud stack started successfully."
