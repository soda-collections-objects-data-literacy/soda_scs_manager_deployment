#!/bin/bash

# Print all commands and their arguments as they are executed.
set -x

# Get the trusted domains from the Nextcloud config
php /var/www/html/occ --no-warnings config:system:get trusted_domains >> trusted_domain.tmp

# If the nextcloud-reverse-proxy domain is not in the trusted domains, add it
if ! grep -q "nextcloud-reverse-proxy" trusted_domain.tmp; then
    # Get the number of trusted domains
    TRUSTED_INDEX=$(cat trusted_domain.tmp | wc -l);
    # Add the nextcloud-reverse-proxy domain to the trusted domains
    php /var/www/html/occ --no-warnings config:system:set trusted_domains $TRUSTED_INDEX --value="nextcloud-reverse-proxy"
fi

rm trusted_domain.tmp

# Install OnlyOffice app
php /var/www/html/occ --no-warnings app:install onlyoffice

# Set basic OnlyOffice configuration
# Set the DocumentServerUrl to the path of the OnlyOffice Document Server
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerUrl --value="/ds-vpath/"
# Set the DocumentServerInternalUrl to the URL of the OnlyOffice Document Server
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice-document-server/"
# Set the StorageUrl to the URL of the Nextcloud Reverse Proxy
php /var/www/html/occ --no-warnings config:system:set onlyoffice StorageUrl --value="http://nextcloud-reverse-proxy/"
# Set the JWT secret
echo ${ONLYOFFICE_JWT_SECRET}
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_secret --value="${ONLYOFFICE_JWT_SECRET}"
