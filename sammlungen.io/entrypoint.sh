#!/bin/bash
set -e

# Wait for database to be ready.
waitForDatabase() {
  echo "Waiting for database to be ready..."
  until mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${SAMMLUNGEN_IO_DB_USER}" -p"${SAMMLUNGEN_IO_DB_PASSWORD}" -e "SELECT 1" "${SAMMLUNGEN_IO_DB_NAME}" >/dev/null 2>&1; do
    echo "Database is unavailable - sleeping"
    sleep 2
  done
  echo "Database is ready."
}

# Check if Drupal is installed by checking if database tables exist.
isDrupalInstalled() {
  echo "Checking if Drupal is installed..."
  tableCount=$(mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${SAMMLUNGEN_IO_DB_USER}" -p"${SAMMLUNGEN_IO_DB_PASSWORD}" "${SAMMLUNGEN_IO_DB_NAME}" -e "SHOW TABLES LIKE 'users';" 2>/dev/null | wc -l)
  if [ "$tableCount" -gt 1 ]; then
    echo "Drupal appears to be installed (found users table)."
    return 0
  else
    echo "Drupal is not installed (no users table found)."
    return 1
  fi
}

# Import database from SQL file.
importDatabase() {
  echo "Looking for SQL files in /var/database_state..."

  # Check if directory exists.
  if [ ! -d "/var/database_state" ]; then
    echo "Warning: /var/database_state directory does not exist."
    echo "Skipping database import."
    return 1
  fi

  # Find the latest SQL file.
  sqlFile=$(find /var/database_state -maxdepth 1 -type f -name "*.sql" -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

  if [ -z "$sqlFile" ]; then
    echo "Warning: No SQL file found in /var/database_state."
    echo "Skipping database import."
    return 1
  fi

  echo "Found SQL file: $sqlFile"
  echo "Importing database..."

  # Import with force flag to continue on errors, and set session variables.
  mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${SAMMLUNGEN_IO_DB_USER}" -p"${SAMMLUNGEN_IO_DB_PASSWORD}" --force \
    --init-command="SET SESSION FOREIGN_KEY_CHECKS=0; SET SESSION SQL_MODE='NO_AUTO_VALUE_ON_ZERO';" \
    "${SAMMLUNGEN_IO_DB_NAME}" < "$sqlFile"

  echo "Database import completed."
}

# Main execution.
main() {
  waitForDatabase

  if ! isDrupalInstalled; then
    importDatabase
  else
    echo "Drupal is already installed, skipping database import."
  fi

  # Start PHP-FPM in background.
  echo "Starting PHP-FPM..."
  php-fpm -D

  # Start NGINX in foreground.
  echo "Starting NGINX..."
  exec "$@"
}

main "$@"
