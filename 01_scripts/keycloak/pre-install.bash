#!/bin/bash

set -e

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if required environment variables are set.

echo "Checking if required environment variables are set..."

# Validate that all environment variables used in the template are set and not empty
# Note: Variables like ${role_*}, ${client_*}, ${authBaseUrl}, ${authAdminUrl}, ${*ScopeConsentText}, ${client_id}
# are Keycloak internal variables that Keycloak substitutes itself, not envsubst.
required_vars=(
    "SCS_DB_ROOT_PASSWORD"
    "JUPYTERHUB_CLIENT_SECRET"
    "JUPYTERHUB_DOMAIN"
    "KC_DB_NAME"
    "KC_DB_PASSWORD"
    "KC_DB_USERNAME"
    "KC_DIDMOS_CLIENT_ID"
    "KC_DIDMOS_CLIENT_SECRET"
    "KC_REALM"
    "NEXTCLOUD_CLIENT_SECRET"
    "NEXTCLOUD_NEXTCLOUD_DOMAIN"
    "SCS_MANAGER_CLIENT_SECRET"
    "SCS_MANAGER_DOMAIN"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not set or is empty."
        exit 1
    fi
done

echo "All required environment variables are set."

echo "Creating Keycloak database and user..."

# Create Keycloak database and user.
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${KC_DB_NAME};"
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${KC_DB_USERNAME}'@'%' IDENTIFIED BY '${KC_DB_PASSWORD}';"
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${KC_DB_NAME}.* TO '${KC_DB_USERNAME}'@'%';"

docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Keycloak database and user created successfully."

echo "Creating OpenID Connect client realm file..."

# Get the script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Create OpenID Connect client config file.
# Only substitute environment variables that are actually used in the template.
# Keycloak internal variables (${role_*}, ${client_*}, ${authBaseUrl}, etc.) are handled by Keycloak itself.
envsubst '${KC_REALM} ${JUPYTERHUB_DOMAIN} ${NEXTCLOUD_NEXTCLOUD_DOMAIN} ${SCS_MANAGER_DOMAIN} ${JUPYTERHUB_CLIENT_SECRET} ${NEXTCLOUD_CLIENT_SECRET} ${SCS_MANAGER_CLIENT_SECRET} ${KC_DIDMOS_CLIENT_SECRET} ${KC_DIDMOS_CLIENT_ID}' < 00_custom_configs/keycloak/templates/realm/scs-realm.json.tpl > keycloak/keycloak/import/scs-realm.json

echo "OpenID Connect client config file created successfully."
