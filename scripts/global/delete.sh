#!/bin/bash
docker compose down
sleep 25
docker volume rm scs-manager_database-data scs-manager_drupal-modules scs-manager_drupal-sites scs-manager_portainer-data scs-manager_drupal-libraries scs-manager_drupal-profiles scs-manager_drupal-themes
docker network rm scs-manager_default
