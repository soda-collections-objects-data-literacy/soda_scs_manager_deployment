#!/usr/bin/env bash
# Fix OnlyOffice "Invalid token" / "invalid signature" error by ensuring Nextcloud
# and the Document Server share the same JWT secret.
#
# Usage: From repo root, run:
#   01_scripts/scs-nextcloud-stack/fix-onlyoffice-jwt.bash
#
# This script will:
# 1. Generate or use existing NEXTCLOUD_ONLYOFFICE_JWT_SECRET from .env
# 2. Set the secret in Nextcloud's OnlyOffice config
# 3. Recreate the OnlyOffice Document Server container with the secret
# 4. Remind you to add the secret to .env for persistence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Load .env if present
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

# Use existing secret from env, or generate a new one.
# Prefer hex (no +/=) to avoid encoding issues; base64 secrets can cause "invalid signature".
if [ "${1:-}" = "--regenerate" ] || [ -z "${NEXTCLOUD_ONLYOFFICE_JWT_SECRET:-}" ]; then
  JWT_SECRET="$(openssl rand -hex 32)"
  echo "Generated new JWT secret (add to .env for persistence)"
else
  JWT_SECRET="$NEXTCLOUD_ONLYOFFICE_JWT_SECRET"
  echo "Using JWT secret from .env"
  # If still getting invalid signature, try: ./fix-onlyoffice-jwt.bash --regenerate
fi

echo "Setting JWT secret in Nextcloud OnlyOffice config..."
docker exec nextcloud--nextcloud php /var/www/html/occ config:system:set onlyoffice jwt_secret --value="$JWT_SECRET"

echo "Recreating OnlyOffice Document Server with JWT secret..."
export NEXTCLOUD_ONLYOFFICE_JWT_SECRET="$JWT_SECRET"
docker compose up -d nextcloud--onlyoffice-document-server

echo ""
echo "Waiting for OnlyOffice to start (30s)..."
sleep 30

echo "Verifying connection..."
if docker exec nextcloud--nextcloud php /var/www/html/occ onlyoffice:documentserver --check 2>/dev/null; then
  echo ""
  echo "✓ OnlyOffice connection successful!"
else
  echo ""
  echo "Connection check failed. The Document Server may need more time to start."
  echo "Try again in a minute: docker exec nextcloud--nextcloud php /var/www/html/occ onlyoffice:documentserver --check"
fi

echo ""
echo "IMPORTANT: Add this to your .env file so the secret persists across restarts:"
echo "  NEXTCLOUD_ONLYOFFICE_JWT_SECRET=$JWT_SECRET"
echo ""
echo "Without it, the Document Server will get an empty secret on next 'docker compose up'"
echo "and you'll see 'Invalid token' / 'invalid signature' again."
