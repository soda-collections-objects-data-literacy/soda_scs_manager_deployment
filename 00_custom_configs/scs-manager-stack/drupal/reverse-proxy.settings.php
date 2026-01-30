<?php

/**
 * @file
 * Reverse proxy configuration for Drupal behind Traefik.
 *
 * This file configures Drupal to properly detect HTTPS when behind
 * a reverse proxy (Traefik) that terminates SSL.
 */

// Enable reverse proxy support.
$settings['reverse_proxy'] = TRUE;

// Trust Docker network ranges (adjust if your networks use different ranges).
$settings['reverse_proxy_addresses'] = ['172.18.0.0/16', '172.19.0.0/16', '172.21.0.0/16'];

// Trust all standard reverse proxy headers.
$settings['reverse_proxy_trusted_headers'] = \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT
  | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO;
