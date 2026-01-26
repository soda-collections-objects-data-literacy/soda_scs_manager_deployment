#!/bin/bash

set -e

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Start Nextcloud service.
echo "Starting Nextcloud service..."
docker compose up -d nextcloud--nextcloud nextcloud--onlyoffice-document-server nextcloud--nextcloud-reverse-proxy nextcloud--onlyoffice-reverse-proxy nextcloud--redis
echo "Nextcloud service started successfully."

echo "Nextcloud stack started successfully."
