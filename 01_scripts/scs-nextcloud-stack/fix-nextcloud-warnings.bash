#!/bin/bash
# Fix common Nextcloud admin warnings in one run.
# Run from repo root. Addresses: proxy headers, .well-known, maintenance window,
# default phone region, AppAPI (disabled), MIME migrations, missing DB indices.
#
# Email must be configured manually via the admin UI if needed.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

echo "=========================================="
echo "Nextcloud: Fixing admin warnings"
echo "=========================================="
echo ""

# 1. Restart reverse proxy to pick up nginx config changes (.well-known URLs, etc.)
echo "Step 1: Restarting Nextcloud reverse proxy..."
docker compose restart nextcloud--nextcloud-reverse-proxy
echo "✓ Reverse proxy restarted."
echo ""

# 2. Disable AppAPI (removes "deploy daemon not set" warning; enable only if you need Ex-Apps)
echo "Step 2: Disabling AppAPI..."
docker exec nextcloud--nextcloud php /var/www/html/occ --no-warnings app:disable app_api 2>/dev/null || true
echo "✓ AppAPI disabled."
echo ""

# 3. Apply proxy, maintenance window, phone region, overwritecondaddr
echo "Step 3: Applying proxy and region settings..."
bash "${SCRIPT_DIR}/apply-nextcloud-proxy-and-region.bash"
echo ""

# 4. Run comprehensive maintenance (MIME migrations, DB indices, etc.)
echo "Step 4: Running maintenance and repair..."
bash "${SCRIPT_DIR}/run-nextcloud-repair.bash"
echo ""

echo "=========================================="
echo "Done! Check the admin panel (Settings → Administration → Overview)"
echo "=========================================="
echo ""
echo "Remaining items (if any) to configure manually:"
echo "  - Email: Settings → Basic settings → Email server"
echo "  - Log errors: Settings → Logging to review and address"
echo ""
