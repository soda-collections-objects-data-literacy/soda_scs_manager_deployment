#!/bin/bash

# SODa SCS Manager Deployment Starter Script
# This script copies override files to their correct locations and executes pre-install scripts.

set -e

# Get the script directory (repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "SODa SCS Manager Deployment Setup"
echo "=========================================="
echo ""

# Load environment variables if .env exists.
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    set -a
    source .env
    set +a
else
    echo "Warning: .env file not found. Some operations may fail."
fi

echo ""
echo "Step 1: Copying docker-compose override files..."
echo "----------------------------------------"

# Define mapping of source override files to destination directories.
declare -A OVERRIDE_MAPPINGS=(
    ["00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml"]="scs-manager-stack/docker-compose.override.yml"
    ["00_custom_configs/scs-nextcloud-stack/docker/docker-compose.override.yml"]="scs-nextcloud-stack/docker-compose.override.yml"
    ["00_custom_configs/scs-project-page/docker/docker-compose.override.yml"]="scs-project-page-stack/docker-compose.override.yml"
    ["00_custom_configs/jupyterhub/docker/docker-compose.override.yml"]="jupyterhub/docker-compose.override.yml"
    ["00_custom_configs/keycloak/docker/docker-compose.override.yml"]="keycloak/docker-compose.override.yml"
)

# Copy override files.
copiedCount=0
skippedCount=0
for source in "${!OVERRIDE_MAPPINGS[@]}"; do
    destination="${OVERRIDE_MAPPINGS[$source]}"
    if [ -f "$source" ]; then
        # Create destination directory if it doesn't exist.
        destDir=$(dirname "$destination")
        if [ ! -d "$destDir" ]; then
            mkdir -p "$destDir"
            echo "Created directory: $destDir"
        fi
        # Check if destination already exists and warn.
        if [ -f "$destination" ]; then
            echo "Warning: Destination file already exists: $destination"
            echo "  Skipping copy to prevent overwrite. Delete manually if you want to update."
            ((skippedCount++))
        else
            cp "$source" "$destination"
            echo "Copied: $source -> $destination"
            ((copiedCount++))
        fi
    else
        echo "Warning: Source file not found: $source"
    fi
done

echo "Copied $copiedCount override file(s)."
if [ $skippedCount -gt 0 ]; then
    echo "Skipped $skippedCount existing file(s) to prevent overwrite."
fi
echo ""

echo "Step 2: Executing pre-install scripts..."
echo "----------------------------------------"

# Find and execute all pre-install scripts.
preInstallScripts=(
    "01_scripts/global/pre-install.bash"
    "01_scripts/keycloak/pre-install.bash"
    "01_scripts/scs-manager-stack/pre-install.bash"
    "01_scripts/scs-nextcloud-stack/pre-install.bash"
    "01_scripts/scs-project-page/pre-install.bash"
)

executedCount=0
for script in "${preInstallScripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "Executing: $script"
            # Execute from repo root to ensure relative paths work correctly.
            bash "$script"
            if [ $? -eq 0 ]; then
                echo "Successfully executed: $script"
                ((executedCount++))
            else
                echo "Error: Failed to execute $script"
                exit 1
            fi
        else
            echo "Warning: Script is not executable: $script"
            echo "Making it executable and retrying..."
            chmod +x "$script"
            bash "$script"
            if [ $? -eq 0 ]; then
                echo "Successfully executed: $script"
                ((executedCount++))
            else
                echo "Error: Failed to execute $script"
                exit 1
            fi
        fi
        echo ""
    else
        echo "Warning: Pre-install script not found: $script"
    fi
done

echo "Executed $executedCount pre-install script(s)."
echo ""

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Ensure Docker networks are created:"
echo "   docker network create reverse-proxy"
echo ""
echo "2. Start all services:"
echo "   docker compose up -d"
echo ""
echo "3. Follow the README.md for additional setup steps."
echo ""
