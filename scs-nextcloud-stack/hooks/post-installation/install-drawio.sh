#!/bin/bash


echo "Installing Draw.io plugin..."
php /var/www/html/occ app:install drawio
echo "Draw.io plugin installed successfully!"

echo "Activating Draw.io plugin..."
php /var/www/html/occ app:enable drawio
echo "Draw.io plugin activated successfully!"
