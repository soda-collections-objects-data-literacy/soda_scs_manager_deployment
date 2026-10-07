#!/usr/bin/env bash
# Shared Docker DNS / container_name defaults for ops scripts.
# Source after `.env` is loaded (or call scs_load_container_names which loads repo-root `.env`).
#
# Naming migration: set SCS_CONTAINER_* in `.env` to the new `{scope}--{service}--{function}`
# values once aliases exist. See docs/technical/service-infrastructure/naming-vocabulary.md.
#
# shellcheck shell=bash

scs_load_container_names() {
  local script_dir repo_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  if [[ -f "${repo_root}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${repo_root}/.env"
    set +a
  fi

  # Defaults = current production DNS (Wave C: MariaDB already renamed).
  : "${SCS_CONTAINER_DATABASE:=core--mariadb--db}"
  : "${SCS_CONTAINER_REVERSE_PROXY:=core--traefik--edge}"
  : "${SCS_CONTAINER_NEXTCLOUD_MOUNTER:=nextcloud-mounter}"
  : "${SCS_CONTAINER_AUTHPROXY:=opengdb--authproxy--proxy}"
  : "${SCS_CONTAINER_RDF4J:=opengdb--rdf4j--db}"
  : "${SCS_CONTAINER_OUTPROXY:=opengdb--outproxy--proxy}"
  : "${SCS_CONTAINER_OPENGDB_PROXY:=opengdb--nginx--edge}"
  : "${SCS_CONTAINER_PORTAINER:=core--portainer--app}"
  : "${SCS_CONTAINER_PHPMYADMIN:=dbms--phpmyadmin--app}"
  : "${SCS_CONTAINER_FORWARD_AUTH:=dbms--forwardauth--proxy}"
  : "${SCS_CONTAINER_ECHO:=core--echo--app}"
  : "${SCS_CONTAINER_HEALTH:=health--health--app}"
  : "${SCS_CONTAINER_KEYCLOAK:=keycloak--keycloak--app}"
  : "${SCS_CONTAINER_MANAGER:=manager--drupal--app}"
  : "${SCS_CONTAINER_MANAGER_REDIS:=manager--redis--cache}"
  : "${SCS_CONTAINER_NEXTCLOUD:=nextcloud--nextcloud--app}"
  : "${SCS_CONTAINER_NEXTCLOUD_REDIS:=nextcloud--redis--cache}"
  : "${SCS_CONTAINER_NEXTCLOUD_EDGE:=nextcloud--nginx--edge}"
  : "${SCS_CONTAINER_ODS:=nextcloud--ods--app}"
  : "${SCS_CONTAINER_ODS_EDGE:=nextcloud--ods--edge}"
  : "${SCS_CONTAINER_JUPYTERHUB:=jupyterhub--jupyterhub--app}"
  : "${SCS_CONTAINER_JUPYTERHUB_BUILDER:=jupyterhub--spawner--builder}"
  : "${SCS_CONTAINER_WEBPROTEGE:=webprotege--webprotege--app}"
  : "${SCS_CONTAINER_WEBPROTEGE_MONGODB:=webprotege--mongodb--db}"

  # Derived URLs (override explicitly if needed).
  : "${NEXTCLOUD_MOUNTER_RC_URL:=http://${SCS_CONTAINER_NEXTCLOUD_MOUNTER}:5572}"
  # Soak: keep INTERNAL_TS_BASE on the authproxy alias until WissKI TS_* /
  # Manager internalHost cutover. Do not derive it from SCS_CONTAINER_AUTHPROXY.
  : "${INTERNAL_TS_BASE:=http://scs--authproxy:8000}"

  # Align common DB host env vars if unset (do not clobber explicit values).
  : "${KC_DB_HOST:=${SCS_CONTAINER_DATABASE}}"
  : "${NEXTCLOUD_DB_HOST:=${SCS_CONTAINER_DATABASE}}"
  : "${SCS_MANAGER_DB_HOST:=${SCS_CONTAINER_DATABASE}}"
  : "${PROJECT_WEBSITE_DB_HOST:=${SCS_CONTAINER_DATABASE}}"
  : "${SCS_DBMS_DEFAULT_SERVER:=${SCS_CONTAINER_DATABASE}}"

  export SCS_CONTAINER_DATABASE SCS_CONTAINER_REVERSE_PROXY \
    SCS_CONTAINER_NEXTCLOUD_MOUNTER SCS_CONTAINER_AUTHPROXY \
    SCS_CONTAINER_RDF4J SCS_CONTAINER_OUTPROXY \
    SCS_CONTAINER_OPENGDB_PROXY SCS_CONTAINER_PORTAINER \
    SCS_CONTAINER_PHPMYADMIN SCS_CONTAINER_FORWARD_AUTH \
    SCS_CONTAINER_ECHO SCS_CONTAINER_HEALTH SCS_CONTAINER_KEYCLOAK \
    SCS_CONTAINER_MANAGER SCS_CONTAINER_MANAGER_REDIS \
    SCS_CONTAINER_NEXTCLOUD SCS_CONTAINER_NEXTCLOUD_REDIS \
    SCS_CONTAINER_NEXTCLOUD_EDGE SCS_CONTAINER_ODS SCS_CONTAINER_ODS_EDGE \
    SCS_CONTAINER_JUPYTERHUB SCS_CONTAINER_JUPYTERHUB_BUILDER \
    SCS_CONTAINER_WEBPROTEGE SCS_CONTAINER_WEBPROTEGE_MONGODB \
    NEXTCLOUD_MOUNTER_RC_URL INTERNAL_TS_BASE \
    KC_DB_HOST NEXTCLOUD_DB_HOST SCS_MANAGER_DB_HOST \
    PROJECT_WEBSITE_DB_HOST SCS_DBMS_DEFAULT_SERVER
}

# If sourced (not executed), apply immediately when BASH_SOURCE[0] != $0 is hard;
# callers should invoke: source …/scs-container-names.bash && scs_load_container_names
# Auto-load when this file is sourced:
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  scs_load_container_names
fi
