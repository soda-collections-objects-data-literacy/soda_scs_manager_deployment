#!/bin/bash

set -e

# Load environment variables.
if [ -f .env ]; then
    source .env
    echo "Loaded environment variables from .env file."
else
    echo "No .env file found. Please create one and set the environment variables. Have you execute the script from the root directory?"
    exit 1
fi

# Check if SCS_DB_ROOT_PASSWORD is set.
if [ -z "${SCS_DB_ROOT_PASSWORD}" ]; then
    echo "Error: SCS_DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

# Check if NEXTCLOUD_DB_NAME is set.
if [ -z "${NEXTCLOUD_DB_NAME}" ]; then
    echo "Error: NEXTCLOUD_DB_NAME environment variable is not set."
    exit 1
fi

# Check if NEXTCLOUD_DB_USER is set.
# Clean up Nextcloud.
read -p "Caution: This operation will permanently delete your database: ${NEXTCLOUD_DB_NAME} and user: ${NEXTCLOUD_DB_USER}. This is not reversible. Are you sure you want to proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Not typed 'yes'. Aborted by user."
    exit 0
fi


echo "Cleaning up Nextcloud..."
docker compose down -v nextcloud--nextcloud nextcloud--onlyoffice-document-server nextcloud--nextcloud-reverse-proxy nextcloud--onlyoffice-reverse-proxy nextcloud--redis

# Drop Nextcloud database and user.
echo "Dropping Nextcloud database and user..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${NEXTCLOUD_DB_NAME};"
echo "Nextcloud database dropped successfully."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP USER IF EXISTS '${NEXTCLOUD_DB_USER}'@'%';"
echo "Nextcloud user dropped successfully."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
echo "Privileges flushed successfully."

echo "Nextcloud cleaned up successfully."
