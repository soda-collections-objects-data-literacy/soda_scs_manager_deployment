#!/bin/bash

# Run Nextcloud maintenance repair and database maintenance tasks.
# This includes:
# - Expensive repair operations (MIME type migrations, etc.)
# - Adding missing database indices
# - Adding missing database columns
# - Adding missing primary keys
#
# Execute after upgrades or when the admin panel reports issues.
# Run from repo root so COMPOSE_FILE and .env are in scope.

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
echo "Nextcloud maintenance and repair"
echo "=========================================="
echo ""

echo "Step 1: Running maintenance:repair --include-expensive..."
echo "This may take a long time on large instances."
$OCC maintenance:repair --include-expensive
echo "✓ Repair complete."
echo ""

echo "Step 2: Adding missing database indices..."
$OCC db:add-missing-indices
echo "✓ Indices updated."
echo ""

echo "Step 3: Adding missing database columns..."
$OCC db:add-missing-columns
echo "✓ Columns updated."
echo ""

echo "Step 4: Adding missing primary keys..."
$OCC db:add-missing-primary-keys
echo "✓ Primary keys updated."
echo ""

echo "=========================================="
echo "All maintenance tasks completed!"
echo "=========================================="
echo ""
echo "Check the Nextcloud admin panel (Settings → Administration → Overview)"
echo "to verify that all warnings have been resolved."
