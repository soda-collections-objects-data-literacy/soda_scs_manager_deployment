#!/bin/bash

set -euo pipefail

# Create user and database for project page.
echo "Creating database: ${PROJECT_WEBSITE_DB_NAME}"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${PROJECT_WEBSITE_DB_NAME};"

echo "Creating user: ${PROJECT_WEBSITE_DB_USER}"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${PROJECT_WEBSITE_DB_USER}'@'%' IDENTIFIED BY '${PROJECT_WEBSITE_DB_PASSWORD}';"

echo "Granting privileges..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${PROJECT_WEBSITE_DB_NAME}.* TO '${PROJECT_WEBSITE_DB_USER}'@'%';"

echo "Flushing privileges..."
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Database setup complete!"

# Generate Varnish VCL configuration from template
echo "Generating Varnish VCL configuration..."

templatePath="00_custom_configs/scs-project-website-stack/varnish/default.vcl.tpl"
outputPath="scs-project-website-stack/varnish/default.vcl"

# Set defaults for Varnish backend configuration (matching docker-compose override)
VARNISH_BACKEND_HOST=${VARNISH_BACKEND_HOST:-scs-project-website--drupal}
VARNISH_BACKEND_PORT=${VARNISH_BACKEND_PORT:-80}

if [ ! -f "$templatePath" ]; then
    echo "Error: Template file not found at $templatePath."
    exit 1
fi

mkdir -p "$(dirname "$outputPath")"
envsubst '${VARNISH_BACKEND_HOST} ${VARNISH_BACKEND_PORT}' < "$templatePath" > "$outputPath"

echo "Varnish VCL configuration generated at $outputPath."
