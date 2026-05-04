#!/bin/bash

# Configure WebProtege OIDC (Keycloak) SSO from the shell.
#
# Updates the WEBPROTEGE_OIDC_* keys in the root .env file (in place) and
# recreates the webprotege container so the new client info takes effect.
#
# Usage:
#   01_scripts/webprotege/configure-oidc.bash \
#       --client-id webprotege \
#       --client-secret <secret> \
#       [--issuer-uri https://auth.example/realms/myrealm] \
#       [--redirect-uri https://webprotege.example/webprotege/oidc/callback] \
#       [--scopes "openid profile email"] \
#       [--username-claim preferred_username] \
#       [--hide-local-login true|false] \
#       [--no-restart] \
#       [--disable]
#
# `--disable` clears all WEBPROTEGE_OIDC_* values in .env (SSO turns off).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

ISSUER_URI=""
CLIENT_ID=""
CLIENT_SECRET=""
REDIRECT_URI=""
SCOPES=""
USERNAME_CLAIM=""
HIDE_LOCAL_LOGIN=""
DISABLE=0
RESTART=1

usage() {
    grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --issuer-uri)        ISSUER_URI="$2"; shift 2 ;;
        --client-id)         CLIENT_ID="$2"; shift 2 ;;
        --client-secret)     CLIENT_SECRET="$2"; shift 2 ;;
        --redirect-uri)      REDIRECT_URI="$2"; shift 2 ;;
        --scopes)            SCOPES="$2"; shift 2 ;;
        --username-claim)    USERNAME_CLAIM="$2"; shift 2 ;;
        --hide-local-login)  HIDE_LOCAL_LOGIN="$2"; shift 2 ;;
        --no-restart)        RESTART=0; shift ;;
        --disable)           DISABLE=1; shift ;;
        -h|--help)           usage 0 ;;
        *) echo "Unknown argument: $1" >&2; usage 1 ;;
    esac
done

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: ${ENV_FILE} not found." >&2
    exit 1
fi

set_env_key() {
    local key="$1"
    local value="$2"
    local escaped
    escaped=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
    if grep -qE "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*$|${key}=${escaped}|" "$ENV_FILE"
    else
        printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

if [ "$DISABLE" -eq 1 ]; then
    echo "Disabling WebProtege OIDC SSO in ${ENV_FILE}"
    for key in WEBPROTEGE_OIDC_ISSUER_URI WEBPROTEGE_OIDC_CLIENT_ID WEBPROTEGE_OIDC_CLIENT_SECRET \
               WEBPROTEGE_OIDC_REDIRECT_URI WEBPROTEGE_OIDC_SCOPES WEBPROTEGE_OIDC_USERNAME_CLAIM \
               WEBPROTEGE_OIDC_HIDE_LOCAL_LOGIN; do
        set_env_key "$key" ""
    done
else
    if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
        echo "Error: --client-id and --client-secret are required (use --disable to turn SSO off)." >&2
        usage 1
    fi
    [ -n "$ISSUER_URI" ]       && set_env_key WEBPROTEGE_OIDC_ISSUER_URI "$ISSUER_URI"
    set_env_key WEBPROTEGE_OIDC_CLIENT_ID     "$CLIENT_ID"
    set_env_key WEBPROTEGE_OIDC_CLIENT_SECRET "$CLIENT_SECRET"
    [ -n "$REDIRECT_URI" ]     && set_env_key WEBPROTEGE_OIDC_REDIRECT_URI "$REDIRECT_URI"
    [ -n "$SCOPES" ]           && set_env_key WEBPROTEGE_OIDC_SCOPES "$SCOPES"
    [ -n "$USERNAME_CLAIM" ]   && set_env_key WEBPROTEGE_OIDC_USERNAME_CLAIM "$USERNAME_CLAIM"
    [ -n "$HIDE_LOCAL_LOGIN" ] && set_env_key WEBPROTEGE_OIDC_HIDE_LOCAL_LOGIN "$HIDE_LOCAL_LOGIN"
    echo "Updated WebProtege OIDC settings in ${ENV_FILE}"
fi

if [ "$RESTART" -eq 1 ]; then
    echo "Recreating webprotege container so the new env takes effect"
    cd "$ROOT_DIR"
    docker compose up -d --force-recreate webprotege
fi

echo "Done."
