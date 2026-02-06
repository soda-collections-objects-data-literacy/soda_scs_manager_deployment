#!/bin/bash

set -euo pipefail

# Get the script directory and repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"
echo "Changed to repository root: ${REPO_ROOT}"

# Load environment variables.
if [ -f .env ]; then
    source .env
    echo "Loaded environment variables from .env file."
else
    echo "Error: No .env file found in ${REPO_ROOT}."
    echo "Please create one and set the required environment variables."
    exit 1
fi

# Check if required environment variables are set.
echo "Checking if required environment variables are set..."
required_vars=(
    "SCS_DB_ROOT_PASSWORD"
    "SCS_MANAGER_DB_NAME"
    "SCS_MANAGER_DB_USER"
    "SCS_MANAGER_DB_PASSWORD"
)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not set or is empty."
        exit 1
    fi
done

echo "All required environment variables are set."

# Create Database.
echo "Creating SCS Manager database..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${SCS_MANAGER_DB_NAME};"
echo "SCS Manager database created successfully."

echo "Creating SCS Manager user..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${SCS_MANAGER_DB_USER}'@'%' IDENTIFIED BY '${SCS_MANAGER_DB_PASSWORD}';"
echo "SCS Manager user created successfully."

echo "Granting privileges..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${SCS_MANAGER_DB_NAME}.* TO '${SCS_MANAGER_DB_USER}'@'%';"
echo "Privileges granted successfully."

echo "Flushing privileges..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
echo "Privileges flushed successfully."

echo "SCS Manager database and user created successfully."

echo "Creating OpenID Connect client config file..."
# Ensure output directory exists
mkdir -p scs-manager-stack/custom_configs
envsubst '${SCS_MANAGER_CLIENT_SECRET} ${KC_SERVICE_NAME} ${SCS_SUBDOMAIN} ${SCS_BASE_DOMAIN} ${KC_REALM}' < 00_custom_configs/scs-manager-stack/openid/openid_connect.client.scs_sso.yml.tpl > scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml
echo "OpenID Connect client config file created successfully."

echo "SCS Manager stack setup completed successfully."
