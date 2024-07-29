#!/bin/bash

mkdir -p ./volumes/drupal/sites
docker run --rm drupal tar -cC /var/www/html/sites . | tar -xC ./volumes/drupal/sites

docker compose up -d