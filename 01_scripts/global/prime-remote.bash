#!/usr/bin/env bash
# Forced SSH command for steering Prime from the dev host.
#
# Install on Prime, root-owned so the deploy user cannot change it:
#   sudo install -o root -g root -m 755 \
#     /var/deploy/soda_scs_manager_deployment/01_scripts/global/prime-remote.bash \
#     /usr/local/bin/scs-prime-remote
# Re-run that command after this file changed; Prime never runs it from the
# checkout, so a `git pull` alone does not widen what the key may do.
#
# ~/.ssh/authorized_keys of the deploy user on Prime (one line):
#   from="<dev host IP>",restrict,command="/usr/local/bin/scs-prime-remote" ssh-ed25519 AAAA… scs-prime-remote
#
# sshd runs this script for every connection with that key and puts what the
# client asked for into SSH_ORIGINAL_COMMAND. Only the subcommands below are
# allowed; arguments are checked against patterns and never reach a shell.
# Run `ssh prime help` for the list. Docs: docs/en/technical/maintenance/dev-to-prime.md

set -euo pipefail
set -f # no globbing of client input

DEPLOY="/var/deploy/soda_scs_manager_deployment"
UPDATE="${DEPLOY}/01_scripts/global/update-stack.bash"
MANAGER="manager--drupal--app"
# Demo version archives are read only from here (path in the manager
# container; on the host: /srv/backups/scs-manager/snapshots/_demo-templates/_incoming).
DEMO_INCOMING="/var/scs-manager/snapshots/_demo-templates/_incoming"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/scs-prime-remote"
LOCK="${STATE}/apply.lock"

die() { echo "scs-prime-remote: $*" >&2; exit 2; }

usage() {
  cat <<'EOF'
Usage: ssh prime <command> [args]

Update (update-stack.bash --prime):
  check [--offline] [--since <sha>]        plan only, changes nothing
  apply [--no-snapshot] [--since <sha>]    start the update detached, then follow its log
  apply-log [--follow]                     log of the running or last apply (exit code at the end)
  apply-status                             running / finished with exit code

Look (read-only):
  status                                   docker compose ps of the deployment
  logs <container> [lines]                 docker logs --tail (default 200, max 5000)
  follow <container> [seconds]             docker logs -f for up to N seconds (default 120, max 1800)
  drush-checks                             updatedb:status, scs:check --problems, enabled themes
  timers                                   systemctl list-timers 'scs-*'
  git-status                               deployment HEAD, submodule status, last --prime --apply

WissKI component versions (SCS Manager):
  wisski-versions                          list entities and the current default
  wisski-version-add <version> <stack> <image> <packages> <default-data-model-recipe> <starter-recipe>
  wisski-set-default <id>                  set wisski.instances.versions.defaultVersion

Demo projects (SCS Manager):
  demo-versions                            list demo versions (status, origin, active, demos)
  demo-import <demo-vX.Y.Z.tar.gz> [--activate]
                                           import an archive from _demo-templates/_incoming
  demo-account                             create/update the service account scs_demo

  help                                     this text
EOF
}

# Client input: $SSH_ORIGINAL_COMMAND over SSH, plain arguments when run locally.
if [[ -n "${SSH_ORIGINAL_COMMAND:-}" ]]; then
  read -r -a ARGS <<<"$SSH_ORIGINAL_COMMAND"
else
  ARGS=("$@")
fi
[[ ${#ARGS[@]} -gt 0 ]] || { usage; exit 0; }

CMD="${ARGS[0]}"
ARGS=("${ARGS[@]:1}")

CLIENT="${SSH_CLIENT:-local}"
logger -t scs-prime-remote -- "user=${USER:-?} from=${CLIENT%% *} cmd=${CMD} args=${ARGS[*]:-}" 2>/dev/null || true

mkdir -p "$STATE"
chmod 700 "$STATE"
cd "$DEPLOY"

# --- argument checks ---------------------------------------------------------

is_sha()       { [[ "$1" =~ ^[0-9a-f]{7,40}$ ]]; }
is_int()       { [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]]; }
is_container() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$ ]] && docker container inspect "$1" >/dev/null 2>&1; }
is_value()     { [[ "$1" =~ ^[0-9A-Za-z][0-9A-Za-z.+_-]{0,63}$ ]]; }
is_entity_id() { [[ "$1" =~ ^[a-z0-9_]{1,64}$ ]]; }
is_demo_archive() { [[ "$1" =~ ^demo-v[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}\.tar\.gz$ ]]; }

# Parses update-stack options. Allowed flags per mode come in $1.
UPDATE_OPTS=()
parse_update_opts() {
  local allowed="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        [[ " $allowed " == *" --since "* ]] || die "--since not allowed here"
        [[ $# -ge 2 ]] && is_sha "$2" || die "--since needs a commit SHA"
        UPDATE_OPTS+=(--since "$2"); shift 2 ;;
      --offline|--no-snapshot)
        [[ " $allowed " == *" $1 "* ]] || die "$1 not allowed here"
        UPDATE_OPTS+=("$1"); shift ;;
      *) die "unknown option: $1" ;;
    esac
  done
}

no_args() { [[ ${#ARGS[@]} -eq 0 ]] || die "${CMD} takes no arguments"; }

# --- apply (detached, survives a dropped connection) ----------------------------

apply_running() {
  [[ -f "${STATE}/apply.pid" ]] && kill -0 "$(cat "${STATE}/apply.pid")" 2>/dev/null
}

follow_apply() {
  local log pid
  log="$(readlink -f "${STATE}/apply-current.log" 2>/dev/null)" || die "no apply has run yet"
  if apply_running; then
    pid="$(cat "${STATE}/apply.pid")"
    tail -n +1 -f --pid="$pid" "$log"
  else
    cat "$log"
  fi
  if [[ -f "${log}.rc" ]]; then
    echo "=== apply finished, exit code $(cat "${log}.rc") (log: ${log})"
    return "$(cat "${log}.rc")"
  fi
  echo "=== apply has no exit code yet (still running or killed); log: ${log}"
  return 3
}

start_apply() {
  local ts log
  if apply_running; then
    die "an apply is already running; use: ssh prime apply-log --follow"
  fi
  ts="$(date +%Y%m%d-%H%M%S)"
  log="${STATE}/apply-${ts}.log"
  : >"$log"
  chmod 600 "$log"
  ln -sfn "$log" "${STATE}/apply-current.log"
  # setsid + nohup: the run keeps going when the SSH connection drops.
  # flock: never two applies at once, also not one started by hand on Prime
  # through this wrapper.
  setsid nohup flock -n "$LOCK" bash -c '
      log="$1"; shift
      "$@"
      echo $? >"${log}.rc"
    ' _ "$log" "$UPDATE" --prime --apply "${UPDATE_OPTS[@]}" \
    >>"$log" 2>&1 </dev/null &
  echo $! >"${STATE}/apply.pid"
  echo "=== apply started (pid $!), log: ${log}"
  echo "=== the run continues if this connection drops; reattach with: ssh prime apply-log --follow"
  sleep 1
  follow_apply
}

# --- drush helpers ---------------------------------------------------------------

manager_up() { docker exec "$MANAGER" true 2>/dev/null || die "${MANAGER} is not running"; }

drush_www() { # drush as www-data, like the site itself
  docker exec -u www-data "$MANAGER" drush "$@"
}

drush_ev() { # $1 = PHP code, values come in as environment variables
  local code="$1"; shift
  docker exec "$@" "$MANAGER" drush ev "$code"
}

# --- dispatch ----------------------------------------------------------------------

case "$CMD" in
  help|-h|--help)
    usage ;;

  check)
    parse_update_opts "--offline --since" "${ARGS[@]}"
    exec "$UPDATE" --prime --check "${UPDATE_OPTS[@]}" ;;

  apply)
    parse_update_opts "--no-snapshot --since" "${ARGS[@]}"
    start_apply ;;

  apply-log)
    if [[ ${#ARGS[@]} -eq 1 && "${ARGS[0]}" == "--follow" ]]; then
      follow_apply
    else
      no_args
      log="$(readlink -f "${STATE}/apply-current.log" 2>/dev/null)" || die "no apply has run yet"
      tail -n 400 "$log"
      [[ -f "${log}.rc" ]] && echo "=== exit code $(cat "${log}.rc")"
    fi ;;

  apply-status)
    no_args
    if apply_running; then
      echo "running (pid $(cat "${STATE}/apply.pid")), log: $(readlink -f "${STATE}/apply-current.log")"
    elif log="$(readlink -f "${STATE}/apply-current.log" 2>/dev/null)" && [[ -f "${log}.rc" ]]; then
      echo "finished, exit code $(cat "${log}.rc"), log: ${log}"
    else
      echo "no apply recorded"
    fi ;;

  status)
    no_args
    docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Image}}' ;;

  logs)
    [[ ${#ARGS[@]} -ge 1 && ${#ARGS[@]} -le 2 ]] || die "usage: logs <container> [lines]"
    is_container "${ARGS[0]}" || die "unknown container: ${ARGS[0]}"
    lines="${ARGS[1]:-200}"
    is_int "$lines" && (( lines <= 5000 )) || die "lines must be 1..5000"
    docker logs --timestamps --tail "$lines" "${ARGS[0]}" 2>&1 ;;

  follow)
    [[ ${#ARGS[@]} -ge 1 && ${#ARGS[@]} -le 2 ]] || die "usage: follow <container> [seconds]"
    is_container "${ARGS[0]}" || die "unknown container: ${ARGS[0]}"
    secs="${ARGS[1]:-120}"
    is_int "$secs" && (( secs <= 1800 )) || die "seconds must be 1..1800"
    timeout "$secs" docker logs --timestamps --tail 50 -f "${ARGS[0]}" 2>&1 || true ;;

  drush-checks)
    no_args
    manager_up
    echo "=== drush updatedb:status"
    docker exec "$MANAGER" drush updatedb:status 2>&1 || true
    echo "=== drush scs:check --problems"
    docker exec "$MANAGER" drush scs:check --problems 2>&1 || true
    echo "=== enabled themes"
    docker exec "$MANAGER" drush pm:list --type=theme --status=enabled --format=list 2>&1 || true ;;

  timers)
    no_args
    systemctl list-timers --all 'scs-*' --no-pager ;;

  git-status)
    no_args
    git log -1 --format='deployment HEAD: %h %s (%cr)'
    [[ -f .git/update-stack-prime.applied ]] && echo "last --prime --apply: $(cat .git/update-stack-prime.applied)"
    git status --short | head -50
    git submodule status --recursive ;;

  wisski-versions)
    no_args
    manager_up
    drush_ev '
      $s = \Drupal::entityTypeManager()->getStorage("soda_scs_wisski_component_ver");
      $d = \Drupal::config("soda_scs_manager.settings")->get("wisski.instances.versions.defaultVersion");
      printf("%-12s %-10s %-8s %-8s %-10s %-14s %-10s %s\n", "id", "version", "stack", "image", "packages", "default-model", "starter", "");
      foreach ($s->loadMultiple() as $e) {
        printf("%-12s %-10s %-8s %-8s %-10s %-14s %-10s %s\n", $e->id(), $e->getVersion(), $e->getWisskiStack(),
          $e->getWisskiImage(), $e->getPackageEnvironment(), $e->getWisskiDefaultDataModelRecipe(),
          $e->getWisskiStarterRecipe(), $e->id() === $d ? "<- default" : "");
      }
    ' ;;

  wisski-version-add)
    [[ ${#ARGS[@]} -eq 6 ]] || die "usage: wisski-version-add <version> <stack> <image> <packages> <default-data-model-recipe> <starter-recipe>"
    for v in "${ARGS[@]}"; do is_value "$v" || die "invalid value: $v"; done
    manager_up
    # Same ID rule as SodaScsWisskiComponentVersionForm::save().
    drush_ev '
      $v = getenv("SCS_V");
      $id = preg_replace("/[^a-z0-9_]/", "_", strtolower($v));
      $s = \Drupal::entityTypeManager()->getStorage("soda_scs_wisski_component_ver");
      foreach ($s->loadMultiple() as $e) {
        if ($e->id() === $id || $e->getVersion() === $v) {
          fwrite(STDERR, "WissKI component version $v already exists (id " . $e->id() . "); nothing changed.\n");
          exit(1);
        }
      }
      $e = $s->create([
        "id" => $id,
        "version" => $v,
        "wisskiStack" => getenv("SCS_STACK"),
        "wisskiImage" => getenv("SCS_IMAGE"),
        "packageEnvironment" => getenv("SCS_PACKAGES"),
        "wisskiDefaultDataModelRecipe" => getenv("SCS_DDM"),
        "wisskiStarterRecipe" => getenv("SCS_STARTER"),
      ]);
      $e->save();
      echo "Created WissKI component version $v (id $id).\n";
    ' -e "SCS_V=${ARGS[0]}" -e "SCS_STACK=${ARGS[1]}" -e "SCS_IMAGE=${ARGS[2]}" \
      -e "SCS_PACKAGES=${ARGS[3]}" -e "SCS_DDM=${ARGS[4]}" -e "SCS_STARTER=${ARGS[5]}" ;;

  wisski-set-default)
    [[ ${#ARGS[@]} -eq 1 ]] && is_entity_id "${ARGS[0]}" || die "usage: wisski-set-default <id>"
    manager_up
    drush_ev '
      $id = getenv("SCS_ID");
      if (!\Drupal::entityTypeManager()->getStorage("soda_scs_wisski_component_ver")->load($id)) {
        fwrite(STDERR, "No WissKI component version with id $id.\n");
        exit(1);
      }
      $c = \Drupal::configFactory()->getEditable("soda_scs_manager.settings");
      $old = $c->get("wisski.instances.versions.defaultVersion");
      $c->set("wisski.instances.versions.defaultVersion", $id)->save();
      echo "defaultVersion: $old -> $id\n";
    ' -e "SCS_ID=${ARGS[0]}" ;;

  demo-versions)
    no_args
    manager_up
    drush_www soda_scs_manager:demo-versions ;;

  demo-import)
    # Only a bare file name from the fixed _incoming directory; the module
    # checks the .sha256 file, the entries and the manifest.
    [[ ${#ARGS[@]} -ge 1 && ${#ARGS[@]} -le 2 ]] && is_demo_archive "${ARGS[0]}" \
      || die "usage: demo-import <demo-vX.Y.Z.tar.gz> [--activate]"
    IMPORT_OPTS=()
    if [[ ${#ARGS[@]} -eq 2 ]]; then
      [[ "${ARGS[1]}" == "--activate" ]] || die "unknown option: ${ARGS[1]}"
      IMPORT_OPTS+=(--activate)
    fi
    manager_up
    drush_www soda_scs_manager:demo-import "${DEMO_INCOMING}/${ARGS[0]}" "${IMPORT_OPTS[@]}" ;;

  demo-account)
    no_args
    manager_up
    # Reads SCS_DEMO_ACCOUNT_PASSWORD (and _EMAIL) from the container environment.
    drush_www soda_scs_manager:demo-account ;;

  *)
    echo "scs-prime-remote: unknown command: ${CMD}" >&2
    usage >&2
    exit 2 ;;
esac
