<?php
$CONFIG = array (
  'maintenance_window_start' => 22,
  'memcache.local' => '\OC\Memcache\APCu',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
    'host' => 'redis',
    'port' => 6379,
  ],
  'default_phone_region' => 'DE',
  'hsts' => true,
  'hstsMaxAge' => 15552000,
  'hstsIncludeSubdomains' => true,
  'trusted_proxies' => [
    0 => '127.0.0.1',
    1 => '10.0.0.0/8',
    2 => '172.16.0.0/12',
    3 => '192.168.0.0/16',
  ],
  'forwarded_for_headers' => ['HTTP_X_FORWARDED_FOR'],

  // Überprüfen ob diese URL-Konfiguration das .well-known Problem löst
  'overwrite.cli.url' => 'https://nextcloud.scs.sammlungen.io',
  'overwritehost' => 'nextcloud.scs.sammlungen.io',
  'overwriteprotocol' => 'https',

  // Vertraue auf alle Nextcloud-Domains
  'trusted_domains' => [
    0 => 'localhost',
    1 => 'nextcloud.scs.sammlungen.io',
    2 => 'scs.sammlungen.io',
    3 => 'office.scs.sammlungen.io',
    4 => 'nextcloud-reverse-proxy',
  ],
);
