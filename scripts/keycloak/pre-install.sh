#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if required environment variables are set.
if [ -z "${DB_ROOT_PASSWORD}" ]; then
    echo "Error: DB_ROOT_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${KC_DB_PASSWORD}" ]; then
    echo "Error: KC_DB_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${KC_DB_NAME}" ]; then
    KC_DB_NAME="keycloak"
fi

if [ -z "${KC_DB_USERNAME}" ]; then
    KC_DB_USERNAME="keycloak"
fi

# Create Keycloak database and user.
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE ${KC_DB_NAME};"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE USER '${KC_DB_USERNAME}'@'%' IDENTIFIED BY '${KC_DB_PASSWORD}';"
docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${KC_DB_NAME}.* TO '${KC_DB_USERNAME}'@'%';"

docker exec -it database mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "Keycloak database and user created successfully."
