#!/bin/bash

# SODa SCS Manager Deployment Starter Script
# This script ensures prerequisites, copies configs, starts database, and executes pre-install scripts.

set -e

# Get the script directory (repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "SODa SCS Manager Deployment Setup"
echo "=========================================="
echo ""

# Step 0: Check prerequisites
echo "Step 0: Checking prerequisites..."
echo "----------------------------------------"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Please copy example-env to .env and configure it:"
    echo "  cp example-env .env"
    echo "  nano .env"
    exit 1
fi
echo "✓ .env file found"

# Load environment variables
echo "Loading environment variables from .env..."
set -a
source .env
set +a
echo "✓ Environment variables loaded"
echo ""

# Step 1: Ensure Docker network exists
echo "Step 1: Ensuring Docker network 'reverse-proxy' exists..."
echo "----------------------------------------"

if docker network inspect reverse-proxy >/dev/null 2>&1; then
    echo "✓ Network 'reverse-proxy' already exists"
else
    echo "Creating network 'reverse-proxy'..."
    docker network create reverse-proxy
    if [ $? -eq 0 ]; then
        echo "✓ Network 'reverse-proxy' created successfully"
    else
        echo "Error: Failed to create network 'reverse-proxy'"
        exit 1
    fi
fi
echo ""

# Step 2: Update git repositories and submodules
echo "Step 2: Updating git repositories and submodules..."
echo "----------------------------------------"

echo "Updating main repository..."
git pull

echo "Initializing and updating submodules..."
git submodule update --init --recursive

echo "Updating submodules to latest commits..."
git submodule update --remote --recursive

echo "✓ All repositories are up to date"
echo ""

# Step 3: Copy docker-compose override files and custom configs
echo "Step 3: Copying docker-compose override files..."
echo "----------------------------------------"

# Define mapping of source override files to destination directories.
declare -A OVERRIDE_MAPPINGS=(
    ["00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml"]="scs-manager-stack/docker-compose.override.yml"
    ["00_custom_configs/scs-nextcloud-stack/docker/docker-compose.override.yml"]="scs-nextcloud-stack/docker-compose.override.yml"
    ["00_custom_configs/scs-project-page/docker/docker-compose.override.yml"]="scs-project-page-stack/docker-compose.override.yml"
    ["00_custom_configs/jupyterhub/docker/docker-compose.override.yml"]="jupyterhub/docker-compose.override.yml"
    ["00_custom_configs/keycloak/docker/docker-compose.override.yml"]="keycloak/docker-compose.override.yml"
    ["00_custom_configs/open_gdb/docker/docker-compose.override.yml"]="open_gdb/docker-compose.override.yml"
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
            skippedCount=$((skippedCount + 1))
        else
            cp "$source" "$destination"
            echo "Copied: $source -> $destination"
            copiedCount=$((copiedCount + 1))
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

# Step 4: Start database service
echo "Step 4: Starting database service..."
echo "----------------------------------------"

# Check if database container is already running (use main compose file)
if COMPOSE_FILE=docker-compose.yml docker compose ps database 2>/dev/null | grep -q "Up"; then
    echo "✓ Database service is already running"
else
    echo "Starting database service..."
    # Use only the main docker-compose.yml to start just the database service
    # This avoids loading all submodule compose files which may have missing env vars
    COMPOSE_FILE=docker-compose.yml docker compose up -d database

    if [ $? -ne 0 ]; then
        echo "Error: Failed to start database service."
        exit 1
    fi
    echo "✓ Database service started"
fi
echo ""

# Step 5: Wait for database to be ready
echo "Step 5: Waiting for database to be ready..."
echo "----------------------------------------"

if [ -z "${SCS_DB_ROOT_PASSWORD}" ]; then
    echo "Warning: SCS_DB_ROOT_PASSWORD not set. Waiting 15 seconds for database to start..."
    sleep 15
    echo "Continuing. Please ensure database is ready before pre-install scripts run."
else
    max_attempts=60
    attempt=0
    db_ready=false

    while [ $attempt -lt $max_attempts ]; do
        # Check if container is running (use main compose file)
        if ! COMPOSE_FILE=docker-compose.yml docker compose ps database 2>/dev/null | grep -q "Up"; then
            attempt=$((attempt + 1))
            echo "  Waiting for database container to start... (attempt $attempt/$max_attempts)"
            sleep 2
            continue
        fi

        # Try to connect to database and verify root user exists
        # Use only main docker-compose.yml for exec commands too
        if COMPOSE_FILE=docker-compose.yml docker compose exec -T database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
            # Verify root user can connect (this confirms root user is created and database is healthy)
            if COMPOSE_FILE=docker-compose.yml docker compose exec -T database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "SHOW DATABASES;" >/dev/null 2>&1; then
                echo "✓ Database is ready and root user is accessible"
                db_ready=true
                break
            fi
        fi
        attempt=$((attempt + 1))
        echo "  Waiting for database to accept connections... (attempt $attempt/$max_attempts)"
        sleep 2
    done

    if [ "$db_ready" = false ]; then
        echo "Warning: Database may not be fully ready. Pre-install scripts may fail."
        echo "You can check database logs with: docker compose logs database"
        echo "Continuing anyway..."
    fi
fi
echo ""

# Step 6: Execute pre-install scripts
echo "Step 6: Executing pre-install scripts..."
echo "----------------------------------------"

# Find and execute all pre-install scripts.
preInstallScripts=(
    "01_scripts/global/pre-install.bash"
    "01_scripts/keycloak/pre-install.bash"
    "01_scripts/scs-manager-stack/pre-install.bash"
    "01_scripts/scs-nextcloud-stack/pre-install.bash"
    "01_scripts/scs-project-page/pre-install.bash"
    "01_scripts/open_gdb/pre-install.bash"
)

executedCount=0
for script in "${preInstallScripts[@]}"; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo "Making script executable: $script"
            chmod +x "$script"
        fi

        echo "Executing: $script"
        # Execute from repo root to ensure relative paths work correctly.
        bash "$script"
        if [ $? -eq 0 ]; then
            echo "✓ Successfully executed: $script"
            executedCount=$((executedCount + 1))
        else
            echo "Error: Failed to execute $script"
            exit 1
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
echo "1. Start all services:"
echo "   docker compose up -d"
echo ""
echo "2. Follow the README.md for additional setup steps."
echo ""
