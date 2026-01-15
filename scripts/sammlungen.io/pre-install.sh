#!/bin/bash

# Load environment variables from parent .env file.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [ -f "${PARENT_DIR}/.env" ]; then
    export $(grep -v '^#' "${PARENT_DIR}/.env" | xargs)
    echo "Loaded environment variables from ${PARENT_DIR}/.env"
else
    echo "Error: .env file not found at ${PARENT_DIR}/.env"
    exit 1
fi

# Load sammlungen.io specific variables if they exist.
if [ -f "${PARENT_DIR}/sammlungen.io/.env" ]; then
    export $(grep -v '^#' "${PARENT_DIR}/sammlungen.io/.env" | xargs)
    echo "Loaded sammlungen.io environment variables"
fi

# Create user and database for sammlungen.io.
echo "Creating database: ${SAMMLUNGEN_IO_DB_NAME}"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${SAMMLUNGEN_IO_DB_NAME};"

echo "Creating user: ${SAMMLUNGEN_IO_DB_USER}"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${SAMMLUNGEN_IO_DB_USER}'@'%' IDENTIFIED BY '${SAMMLUNGEN_IO_DB_PASSWORD}';"

echo "Granting privileges..."
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${SAMMLUNGEN_IO_DB_NAME}.* TO '${SAMMLUNGEN_IO_DB_USER}'@'%';"

echo "Flushing privileges..."
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Database setup complete!"
