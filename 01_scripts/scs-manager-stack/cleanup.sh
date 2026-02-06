#!/bin/bash

set -euo pipefail

# Load environment variables.
if [ -f .env ]; then
    source .env
    echo "Loaded environment variables from .env file."
else
    echo "No .env file found. Please create one and set the environment variables. Have you execute the script from the root directory?"
    exit 1
fi

# Check if required environment variables are set.
echo "Checking if required environment variables are set..."
required_vars=(
    "SCS_DB_ROOT_PASSWORD"
    "SCS_MANAGER_DB_NAME"
    "SCS_MANAGER_DB_USER"
)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not set or is empty."
        exit 1
    fi
done

echo "All required environment variables are set."

# Get the script directory and repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Confirmation prompt.
echo "========================================"
echo "WARNING: This cleanup script will:"
echo "  1. Stop all scs-manager-stack containers"
echo "  2. Delete database: ${SCS_MANAGER_DB_NAME}"
echo "  3. Delete database user: ${SCS_MANAGER_DB_USER}"
echo "  4. Remove OpenID Connect config file"
echo "  5. Optionally remove Docker volumes"
echo "========================================"
read -p "Are you sure you want to continue? (yes/no): " confirmation
if [ "$confirmation" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi
echo ""

# Stop scs-manager-stack services.
echo "Stopping scs-manager-stack containers:"
containerNames=(
    "scs-manager--varnish"
    "scs-manager--drupal"
    "scs-manager--redis"
    "scs-manager--database"
)

for container in "${containerNames[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "  - Stopping and removing: ${container}"
        docker stop "${container}" 2>/dev/null || true
        docker rm "${container}" 2>/dev/null || true
    else
        echo "  - Container not found: ${container}"
    fi
done

echo "Containers stopped and removed."

# Delete database and user.
echo "Deleting from scs--database container:"
echo "  - Database: ${SCS_MANAGER_DB_NAME}"
echo "  - User: ${SCS_MANAGER_DB_USER}"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${SCS_MANAGER_DB_NAME};"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP USER IF EXISTS '${SCS_MANAGER_DB_USER}'@'%';"
docker exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Database and user deleted successfully."

# Remove custom config file.
echo "Removing OpenID Connect client config file..."
configFile="scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml"
if [ -n "$configFile" ] && [ -f "$configFile" ]; then
    rm -f "$configFile"
    echo "Config file removed."
else
    echo "Config file not found, skipping."
fi

# Optionally remove volumes.
echo ""
echo "Docker volumes that can be removed:"
echo "  - scs-manager---database-data (MariaDB data)"
echo "  - scs-manager--drupal-sites (Drupal sites)"
echo "  - scs-manager--redis-data (Redis cache data)"
read -p "Do you want to remove these Docker volumes (this will delete all data)? (yes/no): " removeVolumes
if [ "$removeVolumes" = "yes" ]; then
    echo "Removing Docker volumes..."
    docker volume rm scs-manager---database-data scs-manager--drupal-sites scs-manager--redis-data 2>/dev/null || echo "Some volumes may not exist or are in use."
    echo "Volumes removed."
else
    echo "Docker volumes preserved."
fi

echo "Shutdown completed successfully."
