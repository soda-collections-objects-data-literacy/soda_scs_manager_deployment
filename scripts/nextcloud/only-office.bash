#!/bin/bash

set -x

docker exec -u www-data nextcloud php occ --no-warnings app:install onlyoffice
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice DocumentServerUrl --value="https://office.scs.sammlungen.io/"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice-document-server/"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice StorageUrl --value="https://nextcloud.scs.sammlungen.io/"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice jwt_secret --value="FeatherIsStrongerThanPlastic"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice jwt_header --value="Authorization"
docker exec -u www-data nextcloud php occ --no-warnings config:system:set allow_local_remote_servers --value=true --type=boolean
docker exec -u www-data nextcloud php occ --no-warnings config:system:set onlyoffice verify_peer_off --value=true --type=boolean