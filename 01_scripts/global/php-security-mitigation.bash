#!/usr/bin/env bash
# Temporary mitigation for the PHP request-handling RCEs CVE-2026-109618
# (OOM memory corruption) and CVE-2026-109619 (stale global state), CERT-EU
# Security Advisory 2026-018. Only PHP 8.5.12 / 8.4.27 / 8.3.36 / 8.2.35 fix
# them: rebuild/pull the images once the official php base tags carry those
# versions. Until then this narrows the known attack paths. Safe to re-run.
#
# Usage: 01_scripts/global/php-security-mitigation.bash [audit|apply|revert] [name-regex]
#   audit   list running PHP containers, their PHP version and mitigation (default)
#   apply   mitigate every unpatched PHP container and reload PHP gracefully
#   revert  remove the mitigation files again and reload PHP
#   name-regex  only handle matching containers (e.g. '^wisski-new--drupal$')
#
# apply locks these via php_admin_* (FPM pool / Apache), so neither the app
# nor .user.ini can override them:
#   session.upload_progress.enabled=0     CVE-2026-109619
#   fatal_error_backtraces=0 (PHP 8.5)    CVE-2026-109619
#   memory_limit=-1                       CVE-2026-109618
# Containers without a cgroup memory limit get FALLBACK_MEMORY_LIMIT, so an
# unlimited PHP worker gets OOM-killed instead of exhausting the host.
#
# The files live in the container layer: they survive restarts, not
# recreation. Re-run apply after a container is (re)created from an unpatched
# image, e.g. a new WissKI instance.
set -euo pipefail

MODE="${1:-audit}"
NAME_FILTER="${2:-.}"
FALLBACK_MEMORY_LIMIT="${FALLBACK_MEMORY_LIMIT:-4g}"

INI_FILE=/usr/local/etc/php/conf.d/zzz-sa-2026-018.ini
# zzzz- sorts after every other pool drop-in (e.g. zzz-wisski-socket.conf), so it wins.
POOL_FILE=/usr/local/etc/php-fpm.d/zzzz-sa-2026-018.conf
APACHE_FILE=/etc/apache2/conf-enabled/zzz-sa-2026-018.conf
HEADER="SA 2026-018 (CVE-2026-109618/109619) temporary mitigation; see 01_scripts/global/php-security-mitigation.bash"

# First fixed release of each supported branch; older branches have none.
fixed_release() {
  case "$1" in
    8.5.*) echo 8.5.12 ;;
    8.4.*) echo 8.4.27 ;;
    8.3.*) echo 8.3.36 ;;
    8.2.*) echo 8.2.35 ;;
  esac
}

is_patched() {
  local fixed
  fixed="$(fixed_release "$1")"
  [[ -n "$fixed" && "$(printf '%s\n%s\n' "$fixed" "$1" | sort -V | head -1)" == "$fixed" ]]
}

# Empty for containers without a PHP binary (nginx, redis, distroless, ...).
php_version() {
  timeout 20 docker exec "$1" php -r 'echo PHP_VERSION;' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true
}

php_sapi() {
  docker exec "$1" sh -c 'if command -v php-fpm >/dev/null; then echo fpm; elif command -v apache2ctl >/dev/null; then echo apache; else echo other; fi' 2>/dev/null || echo other
}

is_mitigated() {
  docker exec "$1" test -f "$INI_FILE" 2>/dev/null
}

# Prints "<ini key> <value> <flag|value>" per setting for PHP version $1.
mitigation_settings() {
  echo "session.upload_progress.enabled off flag"
  echo "memory_limit -1 value"
  if [[ "$1" == 8.5.* ]]; then
    echo "fatal_error_backtraces off flag"
  fi
}

write_mitigation() {
  local container="$1" version="$2" sapi="$3" key value kind
  {
    echo "; $HEADER"
    while read -r key value kind; do echo "$key = $value"; done < <(mitigation_settings "$version")
  } | docker exec -i -u 0 "$container" sh -c "cat > $INI_FILE"

  case "$sapi" in
    fpm)
      {
        echo "; $HEADER"
        echo "[www]"
        while read -r key value kind; do echo "php_admin_${kind}[$key] = $value"; done < <(mitigation_settings "$version")
      } | docker exec -i -u 0 "$container" sh -c "cat > $POOL_FILE"
      ;;
    apache)
      {
        echo "# $HEADER"
        echo "<IfModule php_module>"
        while read -r key value kind; do echo "    php_admin_${kind} $key $value"; done < <(mitigation_settings "$version")
        echo "</IfModule>"
      } | docker exec -i -u 0 "$container" sh -c "cat > $APACHE_FILE"
      ;;
  esac
}

config_test() {
  case "$2" in
    fpm) docker exec -u 0 "$1" php-fpm -t >/dev/null 2>&1 ;;
    apache) docker exec -u 0 "$1" apache2ctl -t >/dev/null 2>&1 ;;
    *) return 0 ;;
  esac
}

# Graceful reload. FPM: USR2 to the master only (workers die on USR2); the
# master re-execs in place, so this is safe even when it is PID 1.
reload_php() {
  case "$2" in
    fpm)
      docker exec -u 0 "$1" sh -c '
        for p in /proc/[0-9]*; do
          if tr "\0" " " < "$p/cmdline" 2>/dev/null | grep -q "^php-fpm: master"; then
            kill -USR2 "${p#/proc/}"; exit 0
          fi
        done
        exit 1'
      sleep 2
      docker exec "$1" sh -c 'grep -qa "php-fpm: master" /proc/[0-9]*/cmdline'
      ;;
    apache)
      docker exec -u 0 "$1" apache2ctl -k graceful >/dev/null 2>&1
      ;;
    *)
      echo "  unknown SAPI: restart $1 to load the new php.ini" >&2
      ;;
  esac
}

ensure_memory_limit() {
  if [[ "$(docker inspect -f '{{.HostConfig.Memory}}' "$1")" == 0 ]]; then
    docker update --memory "$FALLBACK_MEMORY_LIMIT" --memory-swap "$FALLBACK_MEMORY_LIMIT" "$1" >/dev/null
    echo "  cgroup memory limit set to $FALLBACK_MEMORY_LIMIT"
  fi
}

apply_mitigation() {
  local container="$1" version="$2" sapi="$3"
  write_mitigation "$container" "$version" "$sapi"
  if ! config_test "$container" "$sapi"; then
    docker exec -u 0 "$container" rm -f "$INI_FILE" "$POOL_FILE" "$APACHE_FILE"
    echo "  FAILED: $sapi config test rejected the mitigation; removed it again" >&2
    return 1
  fi
  ensure_memory_limit "$container"
  if ! reload_php "$container" "$sapi"; then
    echo "  FAILED: $sapi did not come back after the reload; check the container now" >&2
    return 1
  fi
  echo "  mitigated ($sapi)"
}

revert_mitigation() {
  docker exec -u 0 "$1" rm -f "$INI_FILE" "$POOL_FILE" "$APACHE_FILE"
  reload_php "$1" "$2"
  echo "  mitigation removed ($2)"
}

case "$MODE" in
  audit | apply | revert) ;;
  *) echo "Usage: $0 [audit|apply|revert]" >&2; exit 2 ;;
esac

mapfile -t CONTAINERS < <(docker ps --format '{{.Names}}' | grep -E "$NAME_FILTER" | sort || true)

total=0
unpatched=0
failed=0
printf '%-44s %-8s %-7s %-10s %s\n' CONTAINER PHP SAPI STATUS MITIGATION
for container in "${CONTAINERS[@]}"; do
  version="$(php_version "$container")"
  if [[ -z "$version" ]]; then
    continue
  fi
  total=$((total + 1))
  sapi="$(php_sapi "$container")"
  status=patched
  if ! is_patched "$version"; then
    status=VULNERABLE
    unpatched=$((unpatched + 1))
  fi
  mitigation=none
  if is_mitigated "$container"; then
    mitigation=applied
  fi
  printf '%-44s %-8s %-7s %-10s %s\n' "$container" "$version" "$sapi" "$status" "$mitigation"

  case "$MODE" in
    apply)
      if [[ "$status" == VULNERABLE ]]; then
        apply_mitigation "$container" "$version" "$sapi" || failed=$((failed + 1))
      fi
      ;;
    revert)
      if [[ "$mitigation" == applied ]]; then
        revert_mitigation "$container" "$sapi" || failed=$((failed + 1))
      fi
      ;;
  esac
done

echo "Done. $total PHP containers, $unpatched unpatched, $failed failed ($MODE)."
[[ "$failed" == 0 ]]
