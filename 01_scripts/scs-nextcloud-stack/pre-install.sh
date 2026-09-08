#!/bin/bash

set -euo pipefail

# Docker DNS names from .env (naming migration).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../global/scs-container-names.bash"

# Check if SCS_DB_ROOT_PASSWORD is set.
if [ -z "${SCS_DB_ROOT_PASSWORD}" ]; then
    echo "Error: SCS_DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

# Check if NEXTCLOUD_DB_PASSWORD is set.
if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then
    echo "Error: NEXTCLOUD_DB_PASSWORD environment variable is not set."
    exit 1
fi

# Check if NEXTCLOUD_DB_NAME is set.
if [ -z "${NEXTCLOUD_DB_NAME}" ]; then
    echo "NEXTCLOUD_DB_NAME environment variable is not set. Using default value: ${NEXTCLOUD_DB_NAME}"
fi

# Check if NEXTCLOUD_DB_USER is set.
if [ -z "${NEXTCLOUD_DB_USER}" ]; then
    echo "NEXTCLOUD_DB_USER environment variable is not set. Using default value: ${NEXTCLOUD_DB_USER}"
fi

# Check if NEXTCLOUD_DB_PASSWORD is set.
if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then
    echo "Error: NEXTCLOUD_DB_PASSWORD environment variable is not set."
    exit 1
fi

# Create Nextcloud database.
echo "Creating Nextcloud database..."
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${NEXTCLOUD_DB_NAME};"
echo "Nextcloud database created successfully."

echo "Creating Nextcloud user..."
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${NEXTCLOUD_DB_USER}'@'%' IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD}';"
echo "Nextcloud user created successfully."

echo "Granting privileges..."
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${NEXTCLOUD_DB_NAME}.* TO '${NEXTCLOUD_DB_USER}'@'%';"
echo "Privileges granted successfully."

echo "Flushing privileges..."
docker exec "${SCS_CONTAINER_DATABASE}" mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Nextcloud database and user created successfully."
