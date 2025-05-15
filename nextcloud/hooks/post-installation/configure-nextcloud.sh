#!/bin/bash

# Warte, bis Nextcloud bereit ist
until php -f /var/www/html/cron.php > /dev/null 2>&1; do
    echo "Warte auf Nextcloud-Initialisierung..."
    sleep 5
done

echo "Führe Nextcloud-Konfiguration durch..."

# Setze Overwrite-Einstellungen
php /var/www/html/occ config:system:set overwritehost --value="nextcloud.scs.sammlungen.io"
php /var/www/html/occ config:system:set overwriteprotocol --value="https"
php /var/www/html/occ config:system:set overwrite.cli.url --value="https://nextcloud.scs.sammlungen.io"

# Konfiguriere Trusted-Domains
php /var/www/html/occ config:system:delete trusted_domains
php /var/www/html/occ config:system:set trusted_domains 0 --value="localhost"
php /var/www/html/occ config:system:set trusted_domains 1 --value="nextcloud.scs.sammlungen.io"
php /var/www/html/occ config:system:set trusted_domains 2 --value="scs.sammlungen.io"
php /var/www/html/occ config:system:set trusted_domains 3 --value="office.scs.sammlungen.io"
php /var/www/html/occ config:system:set trusted_domains 4 --value="nextcloud-reverse-proxy"

# Konfiguriere Trusted-Proxies
php /var/www/html/occ config:system:delete trusted_proxies
php /var/www/html/occ config:system:set trusted_proxies 0 --value="127.0.0.1"
php /var/www/html/occ config:system:set trusted_proxies 1 --value="10.0.0.0/8"
php /var/www/html/occ config:system:set trusted_proxies 2 --value="172.16.0.0/12"
php /var/www/html/occ config:system:set trusted_proxies 3 --value="192.168.0.0/16"
php /var/www/html/occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"

# Konfiguriere Wartungsfenster
php /var/www/html/occ config:system:set maintenance_window_start --value=22
php /var/www/html/occ config:system:set maintenance_window_length --value=6

# Konfiguriere .well-known URLs
php /var/www/html/occ config:app:set core well-known.config --value='{"webfinger":"OCA\\Federation\\Controller\\FederationController", "nodeinfo":"OCA\\Federation\\Controller\\FederationController", "caldav":"OCA\\DAV\\Controller\\CalDAVController", "carddav":"OCA\\DAV\\Controller\\CardDAVController"}'

echo "Nextcloud-Konfiguration abgeschlossen!"
