#/bin/bash
# Uninstall scs-project-website-stack

set -euo pipefail

# Get the script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

outputPath="scs-project-website-stack/varnish"

rm -r $outputPath
echo "Deleted Varnish config at $outputPath."

# TODO: Delete the user and database
# echo "Creating database: ${PROJECT_WEBSITE_DB_NAME}"
