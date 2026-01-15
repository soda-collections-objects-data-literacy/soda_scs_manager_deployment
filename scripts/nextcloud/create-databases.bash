#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if required environment variables are set.
if [ -z "${DB_ROOT_PASSWORD}" ]; then
    echo "Error: MARIADB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then
    echo "Error: NEXTCLOUD_DB_PASSWORD environment variable is not set."
    exit 1
fi

# nextcloud
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE nextcloud;"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE USER 'nextcloud'@'%' IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD}';"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';"

docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
