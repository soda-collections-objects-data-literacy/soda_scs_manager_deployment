<?php
/**
 * phpMyAdmin SignonScript: returns [user, password] from Keycloak JWT (X-Auth-Token).
 */
declare(strict_types=1);

// phpcs:disable Squiz.Functions.GlobalFunction

/**
 * Returns [username, password] for phpMyAdmin SignonScript auth.
 *
 * @param string $user Existing username (can be empty)
 * @return array{0: string, 1: string}
 */
function get_login_credentials($user)
{
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

    $mysqlUser = $payload['preferred_username'] ?? '';
    if ($mysqlUser === '') {
        $fwdUser = $_SERVER['HTTP_X_FORWARDED_USER'] ?? '';
        $mysqlUser = strpos($fwdUser, '@') !== false ? explode('@', $fwdUser)[0] : $fwdUser;
        $mysqlUser = preg_replace('/[^a-zA-Z0-9_]/', '_', $mysqlUser) ?: '';
    }

    $mysqlPass = $payload['mariadb_password'] ?? '';

    return [$mysqlUser, $mysqlPass];
}
