#!/bin/bash

# Configure Nextcloud email settings from environment variables.
# Run from repo root. Used to apply email config to an existing Nextcloud install.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

CONTAINER_NAME="nextcloud--nextcloud"
OCC="docker exec ${CONTAINER_NAME} php /var/www/html/occ"

echo "=========================================="
echo "Nextcloud Email Configuration"
echo "=========================================="
echo ""

# Check if email config is set in env.
if [ -z "${NEXTCLOUD_NEXTCLOUD_MAIL_MODE}" ] || [ -z "${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST}" ]; then
    echo "Error: Email configuration not found in .env"
    echo ""
    echo "Required variables:"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_MODE=smtp"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST=smtp.example.com"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PORT=587"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_SECURE=tls"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_AUTH=1"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME=user@example.com"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PASSWORD=yourpassword"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS=noreply"
    echo "  NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN=yourdomain.com"
    echo ""
    echo "Or configure via Nextcloud admin UI: Settings → Administration → Basic settings"
    exit 1
fi

echo "Configuring email server..."

# Mail mode (smtp, sendmail, php).
echo "Setting mail mode: ${NEXTCLOUD_NEXTCLOUD_MAIL_MODE}"
$OCC config:system:set mail_smtpmode --value="${NEXTCLOUD_NEXTCLOUD_MAIL_MODE}"

if [ "${NEXTCLOUD_NEXTCLOUD_MAIL_MODE}" = "smtp" ]; then
    # SMTP host and port.
    echo "Setting SMTP host: ${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST}:${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PORT:-587}"
    $OCC config:system:set mail_smtphost --value="${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST}"
    $OCC config:system:set mail_smtpport --value="${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PORT:-587}" --type=integer

    # SMTP encryption (ssl or tls).
    echo "Setting SMTP encryption: ${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_SECURE:-tls}"
    $OCC config:system:set mail_smtpsecure --value="${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_SECURE:-tls}"

    # SMTP authentication.
    if [ "${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_AUTH}" = "1" ] && [ -n "${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME}" ]; then
        echo "Enabling SMTP authentication with user: ${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME}"
        $OCC config:system:set mail_smtpauth --value=1 --type=integer
        $OCC config:system:set mail_smtpname --value="${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME}"
        set -a
        $OCC config:system:set mail_smtppassword --value="${NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PASSWORD}"
        set +a
    else
        echo "SMTP authentication disabled"
        $OCC config:system:set mail_smtpauth --value=0 --type=integer
    fi
fi

# From address.
if [ -n "${NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS}" ]; then
    echo "Setting from address: ${NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS}"
    $OCC config:system:set mail_from_address --value="${NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS}"
fi

# Domain.
if [ -n "${NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN}" ]; then
    echo "Setting mail domain: ${NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN}"
    $OCC config:system:set mail_domain --value="${NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN}"
fi

echo ""
echo "=========================================="
echo "Email configuration complete!"
echo "=========================================="
echo ""
echo "Test the configuration:"
echo "1. Log in to Nextcloud as admin"
echo "2. Go to Settings → Administration → Basic settings"
echo "3. Scroll to Email server section"
echo "4. Click 'Send email' to test"
echo ""
echo "Or test via command line:"
echo "  docker exec ${CONTAINER_NAME} php /var/www/html/occ config:list mail"
