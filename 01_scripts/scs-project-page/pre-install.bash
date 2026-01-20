#!/bin/bash

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Get the script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

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

templatePath="00_custom_configs/scs-project-website/varnish/default.vcl.tpl"
outputPath="scs-project-website-stack/varnish/default.vcl"

# Set defaults for Varnish backend configuration (matching docker-compose override)
export VARNISH_BACKEND_HOST=${VARNISH_BACKEND_HOST:-scs-project-website--drupal}
export VARNISH_BACKEND_PORT=${VARNISH_BACKEND_PORT:-80}

if [ ! -f "$templatePath" ]; then
    echo "Error: Template file not found at $templatePath."
    exit 1
fi

mkdir -p "$(dirname "$outputPath")"
envsubst '${VARNISH_BACKEND_HOST} ${VARNISH_BACKEND_PORT}' < "$templatePath" > "$outputPath"

echo "Varnish VCL configuration generated at $outputPath."
