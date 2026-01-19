#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Create Database.
docker exec scs-manager-database mariadb -h database -u root -p${SCS_DB_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${SCS_MANAGER_DB_NAME};"
docker exec scs-manager-database mariadb -h database -u root -p${SCS_DB_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS '${SCS_MANAGER_DB_USER}'@'%' IDENTIFIED BY '${SCS_MANAGER_DB_PASSWORD}';"
docker exec scs-manager-database mariadb -h database -u root -p${SCS_DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${SCS_MANAGER_DB_NAME}.* TO '${SCS_MANAGER_DB_USER}'@'%';"
docker exec scs-manager-database mariadb -h database -u root -p${SCS_DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"



# Create OpenID Connect client config file.
envsubst '${SCS_MANAGER_CLIENT_SECRET} ${KC_SERVICE_NAME} ${SCS_SUBDOMAIN} ${SCS_HOSTNAME} ${KC_REALM}' < ../00_custom_configs/scs-manager-stack/openid/openid_connect.client.scs_sso.yml.tpl > ../scs-manager-stack/custom_configs/openid_connect.client.scs_sso.yml
