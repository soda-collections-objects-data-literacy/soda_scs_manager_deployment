#!/bin/bash

# Install the Drupal site with SCS Manager

until mysql -h mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "Waiting for MariaDB to be ready..."
  sleep 5
done

# Install the site
drush si --db-url="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@mariadb:3306/${MYSQL_DATABASE}" --site-name="${SITE_NAME}" --account-name="${DRUPAL_USER}" --account-pass="${DRUPAL_PASSWORD}"

# Enable the module
git clone https://github.com/SODa-Collections-Objects-Data-Literacy/scs-manager.git /var/www/html/modules/custom/soda_scs_manager
drush en soda_scs_manager -y

# keep the container running
/usr/sbin/apache2ctl -D FOREGROUND