#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if required environment variables are set.
if [ -z "${ONLYOFFICE_JWT_SECRET}" ]; then
    echo "Error: ONLYOFFICE_JWT_SECRET environment variable is not set."
    exit 1
fi

if [ -z "${SCS_DOMAIN}" ]; then
    echo "Error: SCS_DOMAIN environment variable is not set."
    exit 1
fi

docker exec -u www-data nextcloud php occ --no-warnings app:install onlyoffice
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice DocumentServerUrl --value="https://office.${SCS_DOMAIN}/"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice-document-server/"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice StorageUrl --value="https://nextcloud.${SCS_DOMAIN}/"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice jwt_secret --value="${ONLYOFFICE_JWT_SECRET}"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice jwt_header --value="Authorization"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set allow_local_remote_servers --value=true --type=boolean
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice verify_peer_off --value=true --type=boolean
