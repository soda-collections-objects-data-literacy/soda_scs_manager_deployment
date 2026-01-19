#!/bin/bash

# Print all commands and their arguments as they are executed.
set -x

# Check if required environment variables are set.
if [ -z "${NEXTCLOUD_ONLYOFFICE_JWT_SECRET}" ]; then
    echo "Error: NEXTCLOUD_ONLYOFFICE_JWT_SECRET environment variable is not set."
    exit 1
fi

# Check if required domain variables are set.
if [ -z "${NEXTCLOUD_NEXTCLOUD_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_NEXTCLOUD_DOMAIN environment variable is not set."
    exit 1
fi

if [ -z "${NEXTCLOUD_ONLYOFFICE_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_ONLYOFFICE_DOMAIN environment variable is not set."
    exit 1
fi

# Get the trusted domains from the Nextcloud config.
php /var/www/html/occ --no-warnings config:system:get trusted_domains >> trusted_domain.tmp

# If the nextcloud-reverse-proxy domain is not in the trusted domains, add it.
    if ! grep -q "nextcloud-nextcloud-reverse-proxy" trusted_domain.tmp; then
    # Get the number of trusted domains.
    TRUSTED_INDEX=$(cat trusted_domain.tmp | wc -l);
    # Add the nextcloud-reverse-proxy domain to the trusted domains.
        php /var/www/html/occ --no-warnings config:system:set trusted_domains $TRUSTED_INDEX --value="nextcloud-nextcloud-reverse-proxy"
fi

rm trusted_domain.tmp

# Install OnlyOffice app.
php /var/www/html/occ --no-warnings app:install onlyoffice

# Set OnlyOffice configuration.
# Set the DocumentServerUrl to the external URL of the OnlyOffice Document Server.
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerUrl --value="https://${NEXTCLOUD_ONLYOFFICE_DOMAIN}/"
# Set the DocumentServerInternalUrl to the internal URL of the OnlyOffice Document Server.
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerInternalUrl --value="http://nextcloud-onlyoffice-document-server/"
# Set the StorageUrl to the external URL of Nextcloud.
php /var/www/html/occ --no-warnings config:system:set onlyoffice StorageUrl --value="https://${NEXTCLOUD_NEXTCLOUD_DOMAIN}/"
# Set the JWT secret.
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_secret --value="${NEXTCLOUD_ONLYOFFICE_JWT_SECRET}"
# Set the JWT header.
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_header --value="Authorization"
# Allow local remote servers.
php /var/www/html/occ --no-warnings config:system:set allow_local_remote_servers --value=true --type=boolean
# Disable peer verification for OnlyOffice.
php /var/www/html/occ --no-warnings config:system:set onlyoffice verify_peer_off --value=true --type=boolean
