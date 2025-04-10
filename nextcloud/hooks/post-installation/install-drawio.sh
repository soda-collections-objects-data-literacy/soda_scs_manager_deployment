#!/bin/bash
set -e

echo "Installing Draw.io plugin..."
php /var/www/html/occ app:install drawio
echo "Draw.io plugin installed successfully!"