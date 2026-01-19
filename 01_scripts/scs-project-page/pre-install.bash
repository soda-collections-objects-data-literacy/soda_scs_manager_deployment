#!/bin/bash

# Load environment variables.
if [ -f .env ]; then
    source .env
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
