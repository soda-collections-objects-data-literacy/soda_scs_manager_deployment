#!/bin/bash

# Print all commands and their arguments as they are executed.
set -x

# Check if required environment variables are set.
if [ -z "${ONLYOFFICE_JWT_SECRET}" ]; then
    echo "Error: ONLYOFFICE_JWT_SECRET environment variable is not set."
    exit 1
fi

# Check if SCS_DOMAIN is set. If not, try to use NEXTCLOUD_SLD as fallback.
if [ -z "${SCS_DOMAIN}" ]; then
    if [ -n "${NEXTCLOUD_SLD}" ]; then
        # Construct domain from NEXTCLOUD_SLD if available.
        SCS_DOMAIN="${NEXTCLOUD_SLD}"
        echo "Warning: SCS_DOMAIN not set, using NEXTCLOUD_SLD=${SCS_DOMAIN}"
    else
        echo "Error: SCS_DOMAIN environment variable is not set."
        exit 1
    fi
fi

# Get the trusted domains from the Nextcloud config.
php /var/www/html/occ --no-warnings config:system:get trusted_domains >> trusted_domain.tmp

# If the nextcloud-reverse-proxy domain is not in the trusted domains, add it.
if ! grep -q "nextcloud-reverse-proxy" trusted_domain.tmp; then
    # Get the number of trusted domains.
    TRUSTED_INDEX=$(cat trusted_domain.tmp | wc -l);
    # Add the nextcloud-reverse-proxy domain to the trusted domains.
    php /var/www/html/occ --no-warnings config:system:set trusted_domains $TRUSTED_INDEX --value="nextcloud-reverse-proxy"
fi

rm trusted_domain.tmp

# Install OnlyOffice app.
php /var/www/html/occ --no-warnings app:install onlyoffice

# Set OnlyOffice configuration.
# Set the DocumentServerUrl to the external URL of the OnlyOffice Document Server.
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerUrl --value="https://office.${SCS_DOMAIN}/"
# Set the DocumentServerInternalUrl to the internal URL of the OnlyOffice Document Server.
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice-document-server/"
# Set the StorageUrl to the external URL of Nextcloud.
php /var/www/html/occ --no-warnings config:system:set onlyoffice StorageUrl --value="https://nextcloud.${SCS_DOMAIN}/"
# Set the JWT secret.
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_secret --value="${ONLYOFFICE_JWT_SECRET}"
# Set the JWT header.
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_header --value="Authorization"
# Allow local remote servers.
php /var/www/html/occ --no-warnings config:system:set allow_local_remote_servers --value=true --type=boolean
# Disable peer verification for OnlyOffice.
php /var/www/html/occ --no-warnings config:system:set onlyoffice verify_peer_off --value=true --type=boolean
