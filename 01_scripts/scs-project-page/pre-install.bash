#!/bin/bash

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Create user and database for project page.
echo "Creating database: ${PROJECT_WEBSITE_DB_NAME}"
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${PROJECT_WEBSITE_DB_NAME};"

echo "Creating user: ${PROJECT_WEBSITE_DB_USER}"
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${PROJECT_WEBSITE_DB_USER}'@'%' IDENTIFIED BY '${PROJECT_WEBSITE_DB_PASSWORD}';"

echo "Granting privileges..."
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${PROJECT_WEBSITE_DB_NAME}.* TO '${PROJECT_WEBSITE_DB_USER}'@'%';"

echo "Flushing privileges..."
docker exec database mariadb -u root -p"${SCS_DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Database setup complete!"
