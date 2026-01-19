#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if required environment variables are set.
if [ -z "${DB_ROOT_PASSWORD}" ]; then
    echo "Error: DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then
    echo "Error: NEXTCLOUD_DB_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${NEXTCLOUD_DB_NAME}" ]; then
    NEXTCLOUD_DB_NAME="nextcloud"
fi

if [ -z "${NEXTCLOUD_DB_USER}" ]; then
    NEXTCLOUD_DB_USER="nextcloud"
fi

if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then
    echo "Error: NEXTCLOUD_DB_PASSWORD environment variable is not set."
    exit 1
fi

# Create Nextcloud database.
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE ${NEXTCLOUD_DB_NAME};"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE USER '${NEXTCLOUD_DB_USER}'@'%' IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD}';"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${NEXTCLOUD_DB_NAME}.* TO '${NEXTCLOUD_DB_USER}'@'%';"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
