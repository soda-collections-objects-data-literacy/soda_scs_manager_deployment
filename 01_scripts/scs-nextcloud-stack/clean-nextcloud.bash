#!/bin/bash

set -x

# Check if --skip-env parameter is provided (when called from parent script).
SKIP_LOCAL_ENV=false
if [[ "$1" == "--skip-env" ]] || [[ "$1" == "--no-local-env" ]]; then
    SKIP_LOCAL_ENV=true
fi

# Load environment variables from local .env if not skipped.
if [ "$SKIP_LOCAL_ENV" = false ] && [ -f .env ]; then
    source .env
fi

# Check if MARIADB_ROOT_PASSWORD is set.
if [ -z "${SCS_DB_ROOT_PASSWORD}" ]; then
    echo "Error: SCS_DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

docker compose down nextcloud-nextcloud nextcloud-onlyoffice-document-server nextcloud-nextcloud-reverse-proxy
# Wait for 15 seconds to ensure all containers are properly stopped.
echo "Waiting for 15 seconds to ensure all containers are properly stopped..."
sleep 10
docker volume remove soda_scs_manager_deployment_nextcloud-data soda_scs_manager_deployment_onlyoffice-data soda_scs_manager_deployment_onlyoffice-log
docker exec scs-database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS nextcloud;"
docker exec scs-database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS onlyoffice;"
docker exec scs-database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP USER IF EXISTS 'nextcloud'@'%';"
docker exec scs-database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "DROP USER IF EXISTS 'onlyoffice'@'%';"
docker exec scs-database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
