#!/bin/bash

echo "Configuring Nextcloud..."

# Check if NEXTCLOUD_DOMAIN is set.
if [ -z "${NEXTCLOUD_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_DOMAIN environment variable is not set."
    exit 1
fi

# Check if ONLYOFFICE_DOMAIN is set.
if [ -z "${NEXTCLOUD_ONLYOFFICE_DOMAIN}" ]; then
    echo "Error: ONLYOFFICE_DOMAIN environment variable is not set."
    exit 1
fi

# Check if NEXTCLOUD_ONLYOFFICE_DOCUMENT_SERVER_DOMAIN is set.
if [ -z "${NEXTCLOUD_ONLYOFFICE_DOCUMENT_SERVER_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_ONLYOFFICE_DOCUMENT_SERVER_DOMAIN environment variable is not set."
    exit 1
fi

# Check if NEXTCLOUD_NEXTCLOUD_REVERSE_PROXY_DOMAIN is set.
if [ -z "${NEXTCLOUD_NEXTCLOUD_REVERSE_PROXY_DOMAIN}" ]; then
    echo "Error: NEXTCLOUD_NEXTCLOUD_REVERSE_PROXY_DOMAIN environment variable is not set."
    exit 1
fi

# Check if SCS_MANAGER_DOMAIN is set.
if [ -z "${SCS_MANAGER_DOMAIN}" ]; then
    echo "Error: SCS_MANAGER_DOMAIN environment variable is not set."
    exit 1
fi

# Warte, bis Nextcloud bereit ist.
until php -f /var/www/html/cron.php > /dev/null 2>&1; do
    echo "Warte auf Nextcloud-Initialisierung..."
    sleep 5
done

echo "Führe Nextcloud-Konfiguration durch..."

# Setze Overwrite-Einstellungen für URL-Generierung und interne Checks.
# Diese sind kritisch für .well-known URL Checks von innen.
php /var/www/html/occ config:system:set overwritehost --value="${NEXTCLOUD_DOMAIN}"
php /var/www/html/occ config:system:set overwriteprotocol --value="https"
php /var/www/html/occ config:system:set overwrite.cli.url --value="https://${NEXTCLOUD_DOMAIN}"

# Konfiguriere Trusted-Domains.
php /var/www/html/occ config:system:delete trusted_domains
php /var/www/html/occ config:system:set trusted_domains 0 --value="localhost"
php /var/www/html/occ config:system:set trusted_domains 1 --value="${NEXTCLOUD_DOMAIN}"
php /var/www/html/occ config:system:set trusted_domains 2 --value="${SCS_MANAGER_DOMAIN}"
php /var/www/html/occ config:system:set trusted_domains 3 --value="${NEXTCLOUD_ONLYOFFICE_DOMAIN}"
php /var/www/html/occ config:system:set trusted_domains 4 --value="${NEXTCLOUD_NEXTCLOUD_REVERSE_PROXY_DOMAIN}"

# Konfiguriere Trusted-Proxies und Forwarded-Headers (behebt die Reverse-Proxy-Sicherheitswarnung).
php /var/www/html/occ config:system:delete trusted_proxies
php /var/www/html/occ config:system:set trusted_proxies 0 --value="127.0.0.1"
php /var/www/html/occ config:system:set trusted_proxies 1 --value="10.0.0.0/8"
php /var/www/html/occ config:system:set trusted_proxies 2 --value="172.16.0.0/12"
php /var/www/html/occ config:system:set trusted_proxies 3 --value="192.168.0.0/16"
php /var/www/html/occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
php /var/www/html/occ config:system:set forwarded_host_headers 0 --value="HTTP_X_FORWARDED_HOST"
php /var/www/html/occ config:system:set forwarded_proto_headers 0 --value="HTTP_X_FORWARDED_PROTO"

# Konfiguriere Wartungsfenster (z. B. 22:00 für 6 Stunden).
php /var/www/html/occ config:system:set maintenance_window_start --type integer --value=22
php /var/www/html/occ config:system:set maintenance_window_length --type integer --value=6

# Standard-Telefonregion für Prüfung von Telefonnummern ohne Ländervorwahl (ISO 3166-1, z. B. DE).
if [ -n "${NEXTCLOUD_DEFAULT_PHONE_REGION}" ]; then
    php /var/www/html/occ config:system:set default_phone_region --value="${NEXTCLOUD_DEFAULT_PHONE_REGION}"
fi

# Konfiguriere .well-known URLs.
php /var/www/html/occ config:app:set core well-known.config --value='{"webfinger":"OCA\\Federation\\Controller\\FederationController", "nodeinfo":"OCA\\Federation\\Controller\\FederationController", "caldav":"OCA\\DAV\\Controller\\CalDAVController", "carddav":"OCA\\DAV\\Controller\\CardDAVController"}'

# Konfiguriere E-Mail (falls env vars gesetzt sind).
if [ -n "${NEXTCLOUD_MAIL_MODE}" ] && [ -n "${NEXTCLOUD_MAIL_SMTP_HOST}" ]; then
    echo "Konfiguriere E-Mail-Server..."

    # Mail mode (smtp, sendmail, php).
    php /var/www/html/occ config:system:set mail_smtpmode --value="${NEXTCLOUD_MAIL_MODE}"

    if [ "${NEXTCLOUD_MAIL_MODE}" = "smtp" ]; then
        # SMTP host and port.
        php /var/www/html/occ config:system:set mail_smtphost --value="${NEXTCLOUD_MAIL_SMTP_HOST}"
        php /var/www/html/occ config:system:set mail_smtpport --value="${NEXTCLOUD_MAIL_SMTP_PORT:-587}" --type=integer

        # SMTP encryption (ssl or tls).
        php /var/www/html/occ config:system:set mail_smtpsecure --value="${NEXTCLOUD_MAIL_SMTP_SECURE:-tls}"

        # SMTP authentication.
        if [ "${NEXTCLOUD_MAIL_SMTP_AUTH}" = "1" ] && [ -n "${NEXTCLOUD_MAIL_SMTP_USERNAME}" ]; then
            php /var/www/html/occ config:system:set mail_smtpauth --value=1 --type=integer
            php /var/www/html/occ config:system:set mail_smtpname --value="${NEXTCLOUD_MAIL_SMTP_USERNAME}"
            php /var/www/html/occ config:system:set mail_smtppassword --value="${NEXTCLOUD_MAIL_SMTP_PASSWORD}"
        else
            php /var/www/html/occ config:system:set mail_smtpauth --value=0 --type=integer
        fi
    fi

    # From address.
    if [ -n "${NEXTCLOUD_MAIL_FROM_ADDRESS}" ]; then
        php /var/www/html/occ config:system:set mail_from_address --value="${NEXTCLOUD_MAIL_FROM_ADDRESS}"
    fi

    # Domain.
    if [ -n "${NEXTCLOUD_MAIL_DOMAIN}" ]; then
        php /var/www/html/occ config:system:set mail_domain --value="${NEXTCLOUD_MAIL_DOMAIN}"
    fi

    echo "E-Mail-Server konfiguriert."
else
    echo "E-Mail-Server nicht konfiguriert (env vars nicht gesetzt). Bitte in der Admin-UI konfigurieren."
fi

echo "Nextcloud-Konfiguration abgeschlossen!"
