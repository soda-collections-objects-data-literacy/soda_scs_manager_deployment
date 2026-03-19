<?php
/**
 * phpMyAdmin signon: reads Keycloak JWT (X-Auth-Token), tests MariaDB connection,
 * redirects to index.php on success. Connection test prevents redirect loop when
 * password is wrong. Credentials come from Keycloak only.
 */
declare(strict_types=1);

// Decode JWT payload — token from trusted forward-auth middleware.
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

// Password: per-user Keycloak attribute (mariadb_password) set by SCS Manager.
$mysqlPass = $payload['mariadb_password'] ?? '';
if ($mysqlPass === '') {
    header('Content-Type: text/html; charset=utf-8');
    http_response_code(403);
    echo '<!DOCTYPE html><html><head><title>No DB access</title></head><body>';
    echo '<h1>No database access</h1><p>Your Keycloak account has no MariaDB password. ';
    echo 'Create an SQL component or join a project with SQL databases to get access.</p></body></html>';
    exit;
}

$mysqlHost = getenv('PMA_HOST') ?: 'scs--database';

// Test connection before redirecting — prevents infinite redirect loop when
// password is wrong or user doesn't exist. phpMyAdmin would fail and redirect
// back here; we show the error instead.
$conn = @mysqli_connect($mysqlHost, $mysqlUser, $mysqlPass, '', 3306);
if (!$conn) {
    header('Content-Type: text/html; charset=utf-8');
    http_response_code(503);
    $baseUrl = rtrim(getenv('PMA_ABSOLUTE_URI') ?: 'https://' . ($_SERVER['HTTP_HOST'] ?? '') . '/', '/');
    echo '<!DOCTYPE html><html><head><title>Connection failed</title></head><body>';
    echo '<h1>Database connection failed</h1>';
    echo '<p>MariaDB rejected the credentials. Edit a project with SQL components in SCS Manager to sync your password.</p>';
    echo '<p><a href="' . htmlspecialchars($baseUrl) . '/">Try again</a></p></body></html>';
    exit;
}
mysqli_close($conn);

$baseUrl = rtrim(getenv('PMA_ABSOLUTE_URI') ?: 'https://' . ($_SERVER['HTTP_HOST'] ?? '') . '/', '/');
header('Location: ' . $baseUrl . '/index.php?server=1');
exit;
