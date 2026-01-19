#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Create Database.
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${SCS_MANAGER_DB_NAME};"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${SCS_MANAGER_DB_USER}'@'%' IDENTIFIED BY '${SCS_MANAGER_DB_PASSWORD}';"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${SCS_MANAGER_DB_NAME}.* TO '${SCS_MANAGER_DB_USER}'@'%';"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"



# Get the script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Create OpenID Connect client config file.
# Ensure output directory exists
mkdir -p scs-manager-stack/custom_configs
envsubst '${SCS_MANAGER_CLIENT_SECRET} ${KC_SERVICE_NAME} ${SCS_SUBDOMAIN} ${SCS_HOSTNAME} ${KC_REALM}' < 00_custom_configs/scs-manager-stack/openid/openid_connect.client.scs_sso.yml.tpl > scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml

# Generate Varnish VCL configuration from template
echo "Generating Varnish VCL configuration..."

templatePath="00_custom_configs/scs-manager-stack/varnish/default.vcl.tpl"
outputPath="scs-manager-stack/varnish/default.vcl"

# Set defaults for Varnish backend configuration (matching docker-compose override)
export VARNISH_BACKEND_HOST=${VARNISH_BACKEND_HOST:-scs-manager--drupal}
export VARNISH_BACKEND_PORT=${VARNISH_BACKEND_PORT:-80}

if [ ! -f "$templatePath" ]; then
    echo "Error: Template file not found at $templatePath."
    exit 1
fi

mkdir -p "$(dirname "$outputPath")"
envsubst '${VARNISH_BACKEND_HOST} ${VARNISH_BACKEND_PORT}' < "$templatePath" > "$outputPath"

echo "Varnish VCL configuration generated at $outputPath."
