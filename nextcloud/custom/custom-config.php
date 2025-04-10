<?php
$CONFIG = array (
  'maintenance_window_start' => 1,
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
);
