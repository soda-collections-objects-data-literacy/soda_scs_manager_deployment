<?php
/**
 * phpMyAdmin signon: SignonScript (X-Auth-Token) + SignonURL (fallback). pmadb: SCS_DBMS_PMA_PASSWORD.
 */
declare(strict_types=1);

$signonScript = '/var/www/html/signon-script.php';
$pmaBase = rtrim(getenv('PMA_ABSOLUTE_URI') ?: 'https://' . ($_SERVER['HTTP_HOST'] ?? '') . '/', '/');
$signonUrl = $pmaBase . '/signon.php';
$pmaPass = getenv('SCS_DBMS_PMA_PASSWORD') ?: '';
// KC_LOGOUT_BASE and SCS_DBMS_DOMAIN_PMA are built in docker-compose so ${SCS_SUBDOMAIN} etc. expand
$kcBase = rtrim(getenv('KC_LOGOUT_BASE') ?: 'https://auth.localhost', '/');
$kcRealm = getenv('KC_REALM') ?: 'main';
$dbmsDomain = getenv('SCS_DBMS_DOMAIN_PMA') ?: 'dbms.localhost';
$dbmsClientId = 'https://' . $dbmsDomain;
// Derive manager URL from request host (dbms.X -> manager.X); HTTP_HOST is what the user actually visited
$managerDomain = getenv('SCS_MANAGER_DOMAIN_PMA');
if ($managerDomain === false || $managerDomain === '') {
    $host = $_SERVER['HTTP_HOST'] ?? parse_url($pmaBase, PHP_URL_HOST) ?: '';
    $managerDomain = ($host !== '' && strpos($host, 'dbms.') === 0) ? 'manager.' . substr($host, 5) : (($host !== '') ? 'manager.' . $host : 'manager.localhost');
}
// Logout via forward-auth first to clear the auth cookie on dbms domain; it then redirects to Keycloak
$dbmsBase = 'https://' . $dbmsDomain . '/';
$logoutUrl = $dbmsBase . '_oauth/logout';

foreach (array_keys($cfg['Servers'] ?? []) as $i) {
    $cfg['Servers'][$i]['auth_type'] = 'signon';
    $cfg['Servers'][$i]['SignonScript'] = $signonScript;
    $cfg['Servers'][$i]['SignonURL'] = $signonUrl;
    $cfg['Servers'][$i]['LogoutURL'] = $logoutUrl;
    if ($pmaPass !== '') {
        $cfg['Servers'][$i]['pmadb'] = 'phpmyadmin';
        $cfg['Servers'][$i]['controluser'] = 'pma';
        $cfg['Servers'][$i]['controlpass'] = $pmaPass;
        $cfg['Servers'][$i]['bookmarktable'] = 'pma__bookmark';
        $cfg['Servers'][$i]['column_info'] = 'pma__column_info';
        $cfg['Servers'][$i]['history'] = 'pma__history';
        $cfg['Servers'][$i]['pdf_pages'] = 'pma__pdf_pages';
        $cfg['Servers'][$i]['recent'] = 'pma__recent';
        $cfg['Servers'][$i]['favorite'] = 'pma__favorite';
        $cfg['Servers'][$i]['table_uiprefs'] = 'pma__table_uiprefs';
        $cfg['Servers'][$i]['relation'] = 'pma__relation';
        $cfg['Servers'][$i]['table_coords'] = 'pma__table_coords';
        $cfg['Servers'][$i]['table_info'] = 'pma__table_info';
        $cfg['Servers'][$i]['tracking'] = 'pma__tracking';
        $cfg['Servers'][$i]['userconfig'] = 'pma__userconfig';
        $cfg['Servers'][$i]['users'] = 'pma__users';
        $cfg['Servers'][$i]['usergroups'] = 'pma__usergroups';
        $cfg['Servers'][$i]['navigationhiding'] = 'pma__navigationhiding';
        $cfg['Servers'][$i]['savedsearches'] = 'pma__savedsearches';
        $cfg['Servers'][$i]['central_columns'] = 'pma__central_columns';
        $cfg['Servers'][$i]['designer_settings'] = 'pma__designer_settings';
        $cfg['Servers'][$i]['export_templates'] = 'pma__export_templates';
    }
}
