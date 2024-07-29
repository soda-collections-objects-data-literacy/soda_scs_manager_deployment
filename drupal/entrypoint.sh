#!/bin/bash

env

# Install the Drupal site with SCS Manager

# Install the site
drush site:install \
    --db-url="${DB_HOST}" \
    --db-su="${MYSQL_USER}" \
    --db-su-pw="${MYSQL_DATABASE}" \
    --site-name="${SITE_NAME}" \
    --account-name="${DRUPAL_USER}" \
    --account-pass="${DRUPAL_PASSWORD}" \

# Enable the module
git clone https://github.com/SODa-Collections-Objects-Data-Literacy/scs-manager.git /var/www/html/modules/custom/
drush en scs_manager -y
