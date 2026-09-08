#!/bin/bash

set -euo pipefail

# Docker DNS names from .env (naming migration).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../global/scs-container-names.bash"

# Create user and database for project page.
echo "Creating database: ${PROJECT_WEBSITE_DB_NAME}"
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${PROJECT_WEBSITE_DB_NAME};"

echo "Creating user: ${PROJECT_WEBSITE_DB_USER}"
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${PROJECT_WEBSITE_DB_USER}'@'%' IDENTIFIED BY '${PROJECT_WEBSITE_DB_PASSWORD}';"

echo "Granting privileges..."
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${PROJECT_WEBSITE_DB_NAME}.* TO '${PROJECT_WEBSITE_DB_USER}'@'%';"

echo "Flushing privileges..."
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Database setup complete!"
