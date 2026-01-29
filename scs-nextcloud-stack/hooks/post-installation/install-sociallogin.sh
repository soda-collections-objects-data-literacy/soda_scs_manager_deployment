#!/bin/bash

# Print all commands and their arguments as they are executed.
set -x

if [ -f .env ]; then
    source .env
fi

echo "Installing Social Login plugin..."
php /var/www/html/occ --no-warnings app:install sociallogin
echo "Social Login plugin installed successfully!"

echo "Activating Social Login plugin..."
php /var/www/html/occ --no-warnings app:enable sociallogin
echo "Social Login plugin activated successfully!"

echo "Configuring Social Login settings from environment variables..."

# Basic settings - set only if environment variable is defined.
[ -n "${SOCIALLOGIN_ALLOW_LOGIN_CONNECT}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin allow_login_connect --value="${SOCIALLOGIN_ALLOW_LOGIN_CONNECT}"

[ -n "${SOCIALLOGIN_AUTO_CREATE_GROUPS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin auto_create_groups --value="${SOCIALLOGIN_AUTO_CREATE_GROUPS}"

[ -n "${SOCIALLOGIN_BUTTON_TEXT_WO_PREFIX}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin button_text_wo_prefix --value="${SOCIALLOGIN_BUTTON_TEXT_WO_PREFIX}"

[ -n "${SOCIALLOGIN_CREATE_DISABLED_USERS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin create_disabled_users --value="${SOCIALLOGIN_CREATE_DISABLED_USERS}"

[ -n "${SOCIALLOGIN_DISABLE_NOTIFY_ADMINS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin disable_notify_admins --value="${SOCIALLOGIN_DISABLE_NOTIFY_ADMINS}"

[ -n "${SOCIALLOGIN_DISABLE_REGISTRATION}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin disable_registration --value="${SOCIALLOGIN_DISABLE_REGISTRATION}"

[ -n "${SOCIALLOGIN_HIDE_DEFAULT_LOGIN}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin hide_default_login --value="${SOCIALLOGIN_HIDE_DEFAULT_LOGIN}"

[ -n "${SOCIALLOGIN_NO_PRUNE_USER_GROUPS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin no_prune_user_groups --value="${SOCIALLOGIN_NO_PRUNE_USER_GROUPS}"

[ -n "${SOCIALLOGIN_PREVENT_CREATE_EMAIL_EXISTS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin prevent_create_email_exists --value="${SOCIALLOGIN_PREVENT_CREATE_EMAIL_EXISTS}"

[ -n "${SOCIALLOGIN_RESTRICT_USERS_WO_ASSIGNED_GROUPS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin restrict_users_wo_assigned_groups --value="${SOCIALLOGIN_RESTRICT_USERS_WO_ASSIGNED_GROUPS}"

[ -n "${SOCIALLOGIN_RESTRICT_USERS_WO_MAPPED_GROUPS}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin restrict_users_wo_mapped_groups --value="${SOCIALLOGIN_RESTRICT_USERS_WO_MAPPED_GROUPS}"

[ -n "${SOCIALLOGIN_UPDATE_PROFILE_ON_LOGIN}" ] && \
    php /var/www/html/occ --no-warnings config:app:set sociallogin update_profile_on_login --value="${SOCIALLOGIN_UPDATE_PROFILE_ON_LOGIN}"

# Custom providers configuration - typically a JSON string.
# If SOCIALLOGIN_CUSTOM_PROVIDERS is set, use it directly.
# Otherwise, construct it from Keycloak environment variables.
if [ -n "${SOCIALLOGIN_CUSTOM_PROVIDERS}" ]; then
    php /var/www/html/occ --no-warnings config:app:set sociallogin custom_providers --value="${SOCIALLOGIN_CUSTOM_PROVIDERS}"
    echo "Social Login custom providers configured from SOCIALLOGIN_CUSTOM_PROVIDERS."
elif [ -n "${KC_DOMAIN}" ] && [ -n "${SOCIALLOGIN_KEYCLOAK_REALM}" ] && [ -n "${SOCIALLOGIN_KEYCLOAK_CLIENT_ID}" ] && [ -n "${SOCIALLOGIN_KEYCLOAK_CLIENT_SECRET}" ]; then
    # Construct Keycloak provider JSON from individual environment variables.
    # Structure: {"custom_oidc":[{provider_config}]}
    KEYCLOAK_PROVIDER_JSON="{\"custom_oidc\":[{\"name\":\"keycloak\",\"title\":\"Keycloak\",\"authorizeUrl\":\"https://${KC_DOMAIN}/realms/${SOCIALLOGIN_KEYCLOAK_REALM}/protocol/openid-connect/auth\",\"tokenUrl\":\"https://${KC_DOMAIN}/realms/${SOCIALLOGIN_KEYCLOAK_REALM}/protocol/openid-connect/token\",\"displayNameClaim\":\"${SOCIALLOGIN_KEYCLOAK_DISPLAY_NAME_CLAIM:-username}\",\"userInfoUrl\":\"https://${KC_DOMAIN}/realms/${SOCIALLOGIN_KEYCLOAK_REALM}/protocol/openid-connect/userinfo\",\"logoutUrl\":\"https://${KC_DOMAIN}/realms/${SOCIALLOGIN_KEYCLOAK_REALM}/protocol/openid-connect/logout\",\"clientId\":\"${SOCIALLOGIN_KEYCLOAK_CLIENT_ID}\",\"clientSecret\":\"${SOCIALLOGIN_KEYCLOAK_CLIENT_SECRET}\",\"scope\":\"${SOCIALLOGIN_KEYCLOAK_SCOPE:-openid email groups profile}\",\"groupsClaim\":\"${SOCIALLOGIN_KEYCLOAK_GROUPS_CLAIM:-groups}\",\"style\":\"keycloak\",\"defaultGroup\":\"\"}]}"
    php /var/www/html/occ --no-warnings config:app:set sociallogin custom_providers --value="${KEYCLOAK_PROVIDER_JSON}"
    echo "Social Login Keycloak provider auto-configured from environment variables."
else
    echo "No custom providers configured. Set SOCIALLOGIN_CUSTOM_PROVIDERS or Keycloak environment variables to configure providers."
fi

echo "Social Login configuration completed!"
