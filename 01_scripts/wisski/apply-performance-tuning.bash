#!/usr/bin/env bash
# Apply WissKI performance tuning (PHP-FPM, Varnish timeouts, triplestore URLs)
# without waiting for image rebuilds. Safe to re-run.
#
# Usage: 01_scripts/wisski/apply-performance-tuning.bash
# Env: INTERNAL_TS_BASE (default http://scs--authproxy:8000)
set -euo pipefail

INTERNAL_TS_BASE="${INTERNAL_TS_BASE:-http://scs--authproxy:8000}"
PHP_FPM_CONF_SRC="${PHP_FPM_CONF_SRC:-/home/rnsrk/git/wisski-base-image/config/php-fpm/zz-wisski-production.conf}"

apply_php_fpm() {
  local container="$1"
  if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
    echo "Skip PHP-FPM ($container): not running"
    return 0
  fi
  if [[ ! -f "$PHP_FPM_CONF_SRC" ]]; then
    echo "Skip PHP-FPM ($container): missing $PHP_FPM_CONF_SRC"
    return 0
  fi
  docker cp "$PHP_FPM_CONF_SRC" "${container}:/usr/local/etc/php-fpm.d/zz-wisski-production.conf"
  # Reload PHP-FPM workers only (never signal PID 1 — that stops the container).
  docker exec "$container" sh -c 'if [ -f /usr/local/var/run/php-fpm.pid ]; then kill -USR2 "$(cat /usr/local/var/run/php-fpm.pid)"; elif pgrep -x php-fpm >/dev/null; then pkill -USR2 php-fpm; fi' 2>/dev/null || true
  echo "PHP-FPM tuned: $container"
}

apply_varnish_timeouts() {
  local container="$1"
  if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
    echo "Skip Varnish ($container): not running"
    return 0
  fi
  docker exec "$container" sh -c "sed -i 's/\\.first_byte_timeout = 60s/\\.first_byte_timeout = 600s/; s/\\.between_bytes_timeout = 30s/\\.between_bytes_timeout = 600s/' /etc/varnish/default.vcl" 2>/dev/null || return 0
  docker exec "$container" varnishadm vcl.load perf_tune /etc/varnish/default.vcl 2>/dev/null && docker exec "$container" varnishadm vcl.use perf_tune 2>/dev/null || true
  echo "Varnish timeouts tuned: $container"
}

apply_triplestore_env_and_adapter() {
  local drupal="$1"
  if ! docker ps --format '{{.Names}}' | grep -qx "$drupal"; then
    echo "Skip triplestore ($drupal): not running"
    return 0
  fi
  local repo
  repo="$(docker exec "$drupal" printenv TS_REPOSITORY 2>/dev/null || true)"
  if [[ -z "$repo" ]]; then
    return 0
  fi
  local read_url="${INTERNAL_TS_BASE}/repositories/${repo}"
  local write_url="${read_url}/statements"
  docker exec "$drupal" drush config:set wisski_salz.wisski_salz_adapter.default engine.read_url "$read_url" -y >/dev/null 2>&1 || true
  docker exec "$drupal" drush config:set wisski_salz.wisski_salz_adapter.default engine.write_url "$write_url" -y >/dev/null 2>&1 || true
  docker exec "$drupal" drush cr >/dev/null 2>&1 || true
  echo "Triplestore adapter: $drupal -> $read_url"
}

mapfile -t DRUPAL_CONTAINERS < <(docker ps --format '{{.Names}}' | grep -E '^wisski-.*--drupal$' || true)
mapfile -t VARNISH_CONTAINERS < <(docker ps --format '{{.Names}}' | grep -E '^wisski-.*--varnish$' || true)

for c in "${DRUPAL_CONTAINERS[@]}"; do
  apply_php_fpm "$c"
  apply_triplestore_env_and_adapter "$c"
done

for c in "${VARNISH_CONTAINERS[@]}"; do
  apply_varnish_timeouts "$c"
done

echo "Done. ${#DRUPAL_CONTAINERS[@]} Drupal and ${#VARNISH_CONTAINERS[@]} Varnish containers processed."
