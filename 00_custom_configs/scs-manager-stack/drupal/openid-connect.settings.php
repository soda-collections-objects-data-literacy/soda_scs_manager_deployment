<?php

/**
 * @file
 * OpenID Connect configuration for dual authentication.
 *
 * This file configures OpenID Connect to allow both SSO login (Keycloak)
 * and the default Drupal username/password login form.
 */

// Show SSO login buttons above the standard Drupal login form.
// Options: 'hidden', 'above', 'replace'
$config['openid_connect.settings']['user_login_display'] = 'above';

// Always save user info from the SSO provider.
$config['openid_connect.settings']['always_save_userinfo'] = TRUE;

// Don't automatically connect existing Drupal users with SSO accounts.
$config['openid_connect.settings']['connect_existing_users'] = FALSE;

// Override default registration settings for SSO users.
$config['openid_connect.settings']['override_registration_settings'] = TRUE;

// Enable end session (logout) endpoint.
$config['openid_connect.settings']['end_session_enabled'] = TRUE;

// Redirect after successful login.
$config['openid_connect.settings']['redirect_login'] = '/soda-scs-manager';

// No redirect after logout (stay on current page).
$config['openid_connect.settings']['redirect_logout'] = '';
