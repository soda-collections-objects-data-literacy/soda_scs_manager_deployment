<?php
/**
 * phpMyAdmin signon auth: use SSO user (X-Forwarded-User) as MariaDB username.
 * Set SCS_DBMS_SSO_DB_PASSWORD in env; create MariaDB users for each Keycloak user with that password.
 */
declare(strict_types=1);

$signonUrl = (getenv('PMA_ABSOLUTE_URI') ?: 'https://' . ($_SERVER['HTTP_HOST'] ?? '') . '/') . 'signon.php';
foreach (array_keys($cfg['Servers'] ?? []) as $i) {
    $cfg['Servers'][$i]['auth_type'] = 'signon';
    $cfg['Servers'][$i]['SignonURL'] = $signonUrl;
    $cfg['Servers'][$i]['SignonSession'] = 'PMA_single_signon';
}
