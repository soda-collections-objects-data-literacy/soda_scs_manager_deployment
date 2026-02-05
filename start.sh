#!/bin/bash
# SODa SCS manager deployment starter script
# This script ensures prerequisites, copies configs, starts database, and executes pre-install scripts.

set -euo pipefail

# Get the repo root and script directories
export REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFIG_DIR="$REPO_ROOT/00_custom_configs"
SCRIPTS_DIR="$REPO_ROOT/01_scripts"

# Runs all scripts within base_dir that are named script_name
run_scripts() {
    local script_name="$1"
    local base_dir="$2"
    local count=0

    if [[ -z "$script_name" ]]; then
        echo "Usage: run_scripts <script_name> [base_dir]"
        return 1
    fi

    while IFS= read -r -d '' script; do
        ((count++))
        local dir="$(basename "$(dirname "$script")")"
        local name="$dir/$(basename "$script")"
        local prefix="[$dir]"
        echo "Executing $name..."
        bash "$script" 2>&1 | sed "s|^|$prefix |"
        if [ "${PIPESTATUS[0]}" -eq 0 ]; then
          echo "=> Successfully executed $name"

        else
          echo "$prefix => Failed executing: $name"
          return 1
        fi
        echo ""

      done < <(find "$base_dir" -type f -name "$script_name" -print0)

    echo "Finished running all $count $script_name scripts in $base_dir!"
}


echo "=========================================="
echo "SODa SCS Manager Deployment Setup"
echo "=========================================="
echo ""

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
echo "----------------------------------------"

# TODO: also check for executables: curl, jq, envsubst?

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Please copy example-env to .env and configure it:"
    echo "  cp example-env .env"
    echo "  vim .env"
    exit 1
fi
echo ".env file found..."

# Load environment variables
echo "Loading environment variables from .env..."
set -a
source .env
set +a
echo "Environment variables loaded"
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

echo "All repositories are up to date"
# TODO: this should fail when submodules cannot be initialized
echo ""


echo "Step 3: Starting database service..."
echo "----------------------------------------"

# Check if database container is already running (use main compose file)
if docker compose ps scs--database 2>/dev/null | grep -q "Up"; then
    echo "Database service is already running"
else
    echo "Starting database service..."
    # Use only the main docker-compose.yml to start just the database service
    # This avoids loading all submodule compose files which may have missing env vars
    docker compose up -d scs--database

    if [ $? -ne 0 ]; then
        echo "Error: Failed to start database service."
        exit 1
    fi
    echo "Database service started"
fi
echo ""

echo "Step 4: Waiting for database to be ready..."
echo "----------------------------------------"

if [ -z "${SCS_DB_ROOT_PASSWORD}" ]; then
    echo "Error: SCS_DB_ROOT_PASSWORD not set. Aborting!"
    exit 1
fi

# Check if the database is ready
# Takes the number of attempts as argument
db_ready() {
  max_attempts=${1:-60}
  attempt=0
  db_ready=false

  while [ $attempt -lt $max_attempts ]; do
      # Check if container is running (use main compose file)
      if ! docker compose ps scs--database 2>/dev/null | grep -q "Up"; then
          attempt=$((attempt + 1))
          echo "  Waiting for database container to start... (attempt $attempt/$max_attempts)"
          sleep 2
          continue
      fi

      # Try to connect to database and verify root user exists
      # Use only main docker-compose.yml for exec commands too
      if docker compose exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
          # Verify root user can connect (this confirms root user is created and database is healthy)
          if docker compose exec scs--database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "SHOW DATABASES;" >/dev/null 2>&1; then
              echo "Database is ready and root user is accessible"
              return 0
          fi
      fi
      attempt=$((attempt + 1))
      echo "  Waiting for database to accept connections... (attempt $attempt/$max_attempts)"
      sleep 2
  done
  return 1
}

if ! db_ready; then
  echo "Error: Database is not be fully ready. Aborting!"
  echo "You can check database logs with: docker compose logs scs--database"
  exit 1
fi

echo ""
echo "Step 5: Executing pre-install scripts in $SCRIPTS_DIR..."
echo "----------------------------------------"

# Find and execute all pre-install scripts.
if ! run_scripts "pre-install.sh" "$SCRIPTS_DIR"; then

  echo ""
  echo "=========================================="
  echo "Setup failed! Check your configuration!"
  echo "=========================================="
  exit 1
fi

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
