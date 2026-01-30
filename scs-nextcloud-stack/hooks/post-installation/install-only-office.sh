#!/bin/bash

# Print all commands and their arguments as they are executed.
set -x

echo "Installing OnlyOffice app..."

# Check if required environment variables are set.
if [ -z "${ONLYOFFICE_JWT_SECRET}" ]; then
    echo "Error: ONLYOFFICE_JWT_SECRET environment variable is not set."
    exit 1
fi

# Check if required domain variables are set.
if [ -z "${NEXTCLOUD_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_DOMAIN environment variable is not set."
    exit 1
fi

if [ -z "${ONLYOFFICE_DOCUMENT_SERVER_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_ONLYOFFICE_DOCUMENT_SERVER_DOMAIN environment variable is not set."
    exit 1
fi

if [ -z "${ONLYOFFICE_DOMAIN}" ]; then
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

# Enable OnlyOffice app.
php /var/www/html/occ --no-warnings app:enable onlyoffice
echo "OnlyOffice app enabled successfully!"

# Set OnlyOffice configuration.
# Set the DocumentServerUrl to the external URL of the OnlyOffice Document Server.
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerUrl --value="https://${ONLYOFFICE_DOMAIN}/"
# Set the DocumentServerInternalUrl to the internal URL of the OnlyOffice Document Server.
php /var/www/html/occ --no-warnings config:system:set onlyoffice DocumentServerInternalUrl --value="http://nextcloud--onlyoffice-document-server/"
# Set the StorageUrl to the external URL of Nextcloud.
php /var/www/html/occ --no-warnings config:system:set onlyoffice StorageUrl --value="https://${NEXTCLOUD_DOMAIN}/"
# Set the JWT secret.
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_secret --value="${ONLYOFFICE_JWT_SECRET}"
# Set the JWT header.
php /var/www/html/occ --no-warnings config:system:set onlyoffice jwt_header --value="Authorization"
# Allow local remote servers.
php /var/www/html/occ --no-warnings config:system:set allow_local_remote_servers --value=true --type=boolean
# Disable peer verification for OnlyOffice.
php /var/www/html/occ --no-warnings config:system:set onlyoffice verify_peer_off --value=true --type=boolean

# Enable document preview generation with OnlyOffice.
php /var/www/html/occ --no-warnings config:app:set onlyoffice preview --value="true"
# Enable document version history.
php /var/www/html/occ --no-warnings config:app:set onlyoffice versionHistory --value="true"
# Enable macros for office documents (DOCX, XLSX, PPTX).
php /var/www/html/occ --no-warnings config:app:set onlyoffice customization_macros --value="true"
# Enable plugins for extended functionality.
php /var/www/html/occ --no-warnings config:app:set onlyoffice customization_plugins --value="true"
# Enable forcesave to keep intermediate versions when editing.
php /var/www/html/occ --no-warnings config:app:set onlyoffice customizationForcesave --value="true"

echo "OnlyOffice configuration completed successfully!"
echo ""
echo "Supported editable formats (Office Open XML):"
echo "  - Documents: DOCX, DOCM, DOTX, DOTM"
echo "  - Spreadsheets: XLSX, XLSM, XLTX, XLTM, XLSB"
echo "  - Presentations: PPTX, PPTM, POTX, POTM, PPSX, PPSM"
echo "  - PDF forms: PDF"
echo ""
echo "OpenDocument formats (editable with conversion):"
echo "  - Documents: ODT, OTT, FODT"
echo "  - Spreadsheets: ODS, OTS, FODS"
echo "  - Presentations: ODP, OTP, FODP"
echo ""
echo "Note: ODT/ODS/ODP files can be opened and edited, and will be"
echo "converted to OOXML format internally during editing."
