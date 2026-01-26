#!/bin/bash

set -e

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Stop Nextcloud services.
echo "Stopping Nextcloud services..."
docker compose down nextcloud--nextcloud nextcloud--onlyoffice-document-server nextcloud--nextcloud-reverse-proxy nextcloud--onlyoffice-reverse-proxy nextcloud--redis
echo "Nextcloud services stopped successfully."
