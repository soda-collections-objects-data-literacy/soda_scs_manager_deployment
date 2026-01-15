#!/bin/bash
set -e

echo "Installing Social Login plugin..."
php /var/www/html/occ app:install sociallogin
echo "Social Login plugin installed successfully!"
