<?php
/**
 * phpMyAdmin signon: reads the Keycloak JWT forwarded by traefik-forward-auth
 * (FORWARD_TOKEN_HEADER_NAME=X-Auth-Token) and extracts:
 *   - preferred_username  → MariaDB username
 *   - mariadb_password    → per-user MariaDB password (set by SCS Manager via
 *                           Keycloak user attribute + protocol mapper)
 *
 * Falls back to SCS_DBMS_SSO_DB_PASSWORD env var for users whose attribute has
 * not yet been set (e.g. before their first SQL component was created).
 */
declare(strict_types=1);

session_name('PMA_single_signon');
session_start();

// Decode JWT payload — no signature verification, token comes from trusted middleware.
$payload = [];
$rawToken = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
if ($rawToken !== '') {
    $jwt = preg_replace('/^Bearer\s+/i', '', $rawToken);
    $parts = explode('.', $jwt);
    if (count($parts) === 3) {
        $padded = str_pad(strtr($parts[1], '-_', '+/'), (int) ceil(strlen($parts[1]) / 4) * 4, '=');
        $payload = json_decode(base64_decode($padded), true) ?: [];
    }
}

// Username: Keycloak preferred_username → MariaDB user (set by SCS Manager).
$mysqlUser = $payload['preferred_username'] ?? '';
if ($mysqlUser === '') {
    // Fallback: strip domain from X-Forwarded-User email.
    $fwdUser = $_SERVER['HTTP_X_FORWARDED_USER'] ?? '';
    $mysqlUser = strpos($fwdUser, '@') !== false ? explode('@', $fwdUser)[0] : $fwdUser;
    $mysqlUser = preg_replace('/[^a-zA-Z0-9_]/', '_', $mysqlUser) ?: '';
}

if ($mysqlUser === '') {
    header('Content-Type: text/html; charset=utf-8');
    http_response_code(403);
    echo '<!DOCTYPE html><html><head><title>Not authenticated</title></head><body>';
    echo '<h1>Not authenticated</h1><p>No SSO user. Ensure you are logged in via Keycloak.</p></body></html>';
    exit;
}

// Password: per-user Keycloak attribute (mariadb_password) set by SCS Manager
// when a SQL component is created. Falls back to the shared SSO password.
$mysqlPass = $payload['mariadb_password'] ?? getenv('SCS_DBMS_SSO_DB_PASSWORD') ?: '';
$mysqlHost = getenv('PMA_HOST') ?: 'scs--database';

$_SESSION['PMA_single_signon_user'] = $mysqlUser;
$_SESSION['PMA_single_signon_password'] = $mysqlPass;
$_SESSION['PMA_single_signon_host'] = $mysqlHost;
$_SESSION['PMA_single_signon_port'] = 3306;
session_write_close();

$base = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/');
header('Location: ' . $base . '/index.php');
exit;
