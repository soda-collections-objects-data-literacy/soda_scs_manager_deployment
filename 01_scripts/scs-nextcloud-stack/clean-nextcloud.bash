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
if [ -z "${MARIADB_ROOT_PASSWORD}" ]; then
    echo "Error: MARIADB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

docker compose down nextcloud onlyoffice-document-server nextcloud-reverse-proxy
# Wait for 15 seconds to ensure all containers are properly stopped.
echo "Waiting for 15 seconds to ensure all containers are properly stopped..."
sleep 10
docker volume remove soda_scs_manager_deployment_nextcloud-data soda_scs_manager_deployment_onlyoffice-data soda_scs_manager_deployment_onlyoffice-log
docker exec -it database mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DROP DATABASE nextcloud;"
docker exec -it database mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DROP DATABASE onlyoffice;"
docker exec -it database mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DROP USER 'nextcloud'@'%';"
docker exec -it database mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DROP USER 'onlyoffice'@'%';"
docker exec -it database mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
