#!/bin/bash

set -x

docker compose down nextcloud onlyoffice-document-server nextcloud-reverse-proxy
# Wait for 15 seconds to ensure all containers are properly stopped
echo "Waiting for 15 seconds to ensure all containers are properly stopped..."
sleep 10
docker volume remove soda_scs_manager_deployment_nextcloud-data soda_scs_manager_deployment_onlyoffice-data soda_scs_manager_deployment_onlyoffice-log
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "DROP DATABASE nextcloud;"
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "DROP DATABASE onlyoffice;"
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "DROP USER 'nextcloud'@'%';"
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "DROP USER 'onlyoffice'@'%';"
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "FLUSH PRIVILEGES;"
