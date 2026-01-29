#!/bin/bash

# Apply Nextcloud reverse-proxy headers, phone region, and email settings to an existing install.
# Run from repo root. Use after fixing admin warnings about proxy headers, phone region, or email.

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

# Fix overwrite settings for .well-known checks (critical for internal checks to work).
if [ -n "${NEXTCLOUD_NEXTCLOUD_DOMAIN}" ]; then
    echo "Setting overwrite URLs to ${NEXTCLOUD_NEXTCLOUD_DOMAIN}..."
    $OCC config:system:set overwritehost --value="${NEXTCLOUD_NEXTCLOUD_DOMAIN}"
    $OCC config:system:set overwriteprotocol --value="https"
    $OCC config:system:set overwrite.cli.url --value="https://${NEXTCLOUD_NEXTCLOUD_DOMAIN}"
    echo "✓ Overwrite URLs set."
    echo ""
fi

echo "Setting trusted proxies and forwarded headers..."
$OCC config:system:delete trusted_proxies 2>/dev/null || true
$OCC config:system:set trusted_proxies 0 --value="127.0.0.1"
$OCC config:system:set trusted_proxies 1 --value="10.0.0.0/8"
$OCC config:system:set trusted_proxies 2 --value="172.16.0.0/12"
$OCC config:system:set trusted_proxies 3 --value="192.168.0.0/16"
$OCC config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
$OCC config:system:set forwarded_host_headers 0 --value="HTTP_X_FORWARDED_HOST"
$OCC config:system:set forwarded_proto_headers 0 --value="HTTP_X_FORWARDED_PROTO"

echo "Setting maintenance window (22:00, 6 hours)..."
$OCC config:system:set maintenance_window_start --type integer --value=22
$OCC config:system:set maintenance_window_length --type integer --value=6

if [ -n "${NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION}" ]; then
    echo "Setting default_phone_region to ${NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION}..."
    $OCC config:system:set default_phone_region --value="${NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION}"
else
    echo "NEXTCLOUD_NEXTCLOUD_DEFAULT_PHONE_REGION not set; skipping default_phone_region."
fi

echo "Done."
