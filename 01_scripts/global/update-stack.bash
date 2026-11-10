#!/usr/bin/env bash
# Check the deployment repo and all submodules for new commits/releases,
# fast-forward them, rebuild services whose build context changed and
# restart services whose bind-mounted config changed.
#
# Usage:
#   01_scripts/global/update-stack.bash --check            # fetch + show plan, change nothing
#   01_scripts/global/update-stack.bash --apply            # pull, build, recreate, restart
#   options: --no-images        skip `docker compose pull` for image-only services
#            --only a,b         limit submodules (deployment repo is always checked)
#            --skip-deployment  do not pull the deployment repo itself
#            --offline          do not fetch, use already fetched remote refs
#
# Prime (production): 01_scripts/global/update-stack.bash --prime --check|--apply
#   Follows the submodule pointers recorded in the deployment repo (no --remote),
#   copies the derived overrides, prints systemd unit commands, snapshots all
#   databases, rebuilds/recreates what changed, updates the SCS Manager image,
#   runs the Drupal checks and lists the manual steps.
#   options: --since <rev>      deployment commit to diff from (default: last --prime --apply)
#            --no-snapshot      skip the database snapshot
#            --offline          no fetch, plan from what is already fetched
#   Docs: docs/en/technical/maintenance/dev-to-prime.md
#
# Tracking mode per submodule (override in .gitmodules: `scs-track = release|branch`):
#   release  HEAD sits exactly on a SemVer tag -> move to the newest SemVer tag
#   branch   otherwise -> fast-forward the current branch (detached: origin/HEAD)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE=""
PULL_IMAGES=1
ONLY=""
SKIP_DEPLOYMENT=0
OFFLINE=0
PRIME=0
SNAPSHOT=1
SINCE=""
SEMVER_RE='^v?[0-9]+\.[0-9]+\.[0-9]+$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE=check ;;
    --apply) MODE=apply ;;
    --no-images) PULL_IMAGES=0 ;;
    --only) ONLY="$2"; shift ;;
    --skip-deployment) SKIP_DEPLOYMENT=1 ;;
    --offline) OFFLINE=1 ;;
    --prime) PRIME=1 ;;
    --no-snapshot) SNAPSHOT=0 ;;
    --since) SINCE="$2"; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[[ -n "$MODE" ]] || { echo "Specify --check or --apply (see --help)" >&2; exit 2; }

for bin in git jq docker; do
  command -v "$bin" >/dev/null || { echo "Missing dependency: $bin" >&2; exit 1; }
done

exec 9>"${REPO_ROOT}/.git/update-stack.lock"
flock -n 9 || { echo "Another update-stack run is in progress." >&2; exit 1; }

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
hr()   { printf '%s\n' "------------------------------------------------------------"; }

# Prints the newest SemVer tag of the repo in $1.
newest_semver_tag() {
  git -C "$1" tag --list | grep -E "$SEMVER_RE" | sort -V | tail -1 || true
}

# Prints the branch a submodule should follow.
follow_branch() {
  local path="$1" name="$2" b
  b="$(git -C "$path" branch --show-current)"
  [[ -n "$b" ]] || b="$(git config -f .gitmodules "submodule.${name}.branch" || true)"
  [[ -n "$b" ]] || b="$(git -C "$path" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
  [[ -n "$b" ]] || b=main
  printf '%s' "$b"
}

# Collected plan entries: "repo|path|mode|from|to|target_ref|state"
declare -a PLAN=()
CHANGED_FILES="$(mktemp)"
trap 'rm -f "$CHANGED_FILES"' EXIT

record_changes() { # repo_path from to
  local path="$1" from="$2" to="$3" prefix=""
  [[ "$path" == "." ]] || prefix="${path}/"
  git -C "$path" diff --name-only "$from" "$to" | sed "s|^|${REPO_ROOT}/${prefix}|" >>"$CHANGED_FILES"
}

# Sets COMPOSE_JSON, REBUILD and RESTART from the paths in $CHANGED_FILES:
# services whose build context or Dockerfile changed, and services whose
# bind-mounted files changed.
compute_impact() {
  COMPOSE_JSON="$(docker compose config --format json 2>/dev/null)" || { warn "docker compose config failed"; COMPOSE_JSON='{"services":{}}'; }

  IMPACT="$(jq -R . "$CHANGED_FILES" | jq -s --argjson cfg "$COMPOSE_JSON" '
    def under($root): . as $p | ($p == $root) or ($p | startswith($root + "/"));
    . as $changed
    | [$cfg.services | to_entries[] | . as $s
       | ($s.value.build // null) as $b
       | ( if $b then
             [$b.context]
             + ( if ($b.dockerfile // null) == null then []
                 elif ($b.dockerfile | startswith("/")) then [$b.dockerfile]
                 else [$b.context + "/" + $b.dockerfile] end )
           else [] end ) as $buildRoots
       | ([$s.value.volumes[]? | select(.type == "bind") | .source]) as $binds
       | { service: $s.key,
           rebuild: ([$changed[] as $p | $buildRoots[] as $r | select($p | under($r))] | length > 0),
           restart: ([$changed[] as $p | $binds[] as $r | select($p | under($r))] | length > 0) } ]
    | { rebuild: [.[] | select(.rebuild) | .service],
        restart: [.[] | select(.restart and (.rebuild | not)) | .service] }')"

  mapfile -t REBUILD < <(jq -r '.rebuild[]' <<<"$IMPACT")
  mapfile -t RESTART < <(jq -r '.restart[]' <<<"$IMPACT")
}

# ================================================================ prime mode
# Production follows the submodule pointers recorded in the deployment repo.
# Steps and background: docs/en/technical/maintenance/dev-to-prime.md.

MANAGER_SVC="manager--drupal--app"
NEXTCLOUD_SVC="nextcloud--nextcloud--app"
PRIME_STATE_FILE="${REPO_ROOT}/.git/update-stack-prime.applied"
PRIME_BACKUP_ROOT="${SCS_UPDATE_BACKUP_DIR:-/srv/backups/pre-update}"
MANAGER_WAIT_SECONDS="${MANAGER_WAIT_SECONDS:-900}"
MANAGER_CHANGELOG="/opt/drupal/web/modules/contrib/soda_scs_manager/CHANGELOG.md"
SYSTEMD_DIR="/etc/systemd/system"
# Gitignored copies inside the stacks that Compose reads instead of the source.
DERIVED_OVERRIDES=(
  "00_custom_configs/scs-manager-stack/docker/docker-compose.override.yml|scs-manager-stack/docker-compose.override.yml"
  "00_custom_configs/scs-project-website-stack/docker/docker-compose.override.yml|scs-project-website-stack/docker-compose.override.yml"
)
ALLOWED_THEMES=" scs_custom_theme gin claro olivero stable9 stark starterkit_theme "

GIT_NET=(git)
declare -a BLOCKERS=() TODOS=() PRIME_MOVES=() COPY_NOW=() UNIT_CMDS=()

# Prints the value of a variable from .env (last assignment, quotes stripped).
env_get() {
  sed -n "s/^${1}=//p" .env | tail -1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

# SSH runs in batch mode, so it never asks for a passphrase. Without a usable
# key, public GitHub repos are read over HTTPS instead. Nothing is pushed.
prime_net_setup() {
  export GIT_TERMINAL_PROMPT=0
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes"
  [[ $OFFLINE -eq 1 ]] && return 0
  if ! git ls-remote --exit-code origin HEAD </dev/null >/dev/null 2>&1; then
    GIT_NET=(git -c "url.https://github.com/.insteadOf=git@github.com:")
    log "SSH needs a passphrase or key here; reading over HTTPS instead."
  fi
}

# Makes sure commit $2 exists in the submodule at $1 (.gitmodules URL $3).
prime_have_commit() {
  local path="$1" sha="$2" url="$3"
  git -C "$path" cat-file -e "${sha}^{commit}" 2>/dev/null && return 0
  [[ $OFFLINE -eq 1 ]] && return 1
  "${GIT_NET[@]}" -C "$path" fetch --quiet --all --tags </dev/null 2>/dev/null || true
  git -C "$path" cat-file -e "${sha}^{commit}" 2>/dev/null && return 0
  "${GIT_NET[@]}" -C "$path" fetch --quiet "$url" "$sha" </dev/null 2>/dev/null || true
  git -C "$path" cat-file -e "${sha}^{commit}" 2>/dev/null
}

# Prints the bind mounts in the manager's compose config (what the next
# container gets, not the running one) that hide the module or theme shipped
# in the image.
manager_shadow_binds() {
  jq -r --arg s "$MANAGER_SVC" \
    '.services[$s].volumes[]? | select(.type == "bind") | "bind \(.source) -> \(.target)"' <<<"$COMPOSE_JSON" \
    | grep -E '^bind .* -> /opt/drupal/web/(themes|modules)/[^ ]*/(scs_custom_theme|soda_scs_manager)$' || true
}

# Prints "service<TAB>running image<TAB>configured image" where the two differ.
image_tag_changes() {
  LC_ALL=C join -t $'\t' \
    <(docker compose ps --format '{{.Service}}\t{{.Image}}' 2>/dev/null | LC_ALL=C sort) \
    <(jq -r '.services | to_entries[] | select(.value.image) | "\(.key)\t\(.value.image)"' <<<"$COMPOSE_JSON" | LC_ALL=C sort) \
    | awk -F '\t' '$2 != $3'
}

# Prints the services a plain `up -d` would create or recreate right now.
compose_recreate_preview() {
  [[ $# -gt 0 ]] || return 0
  docker compose up -d --dry-run --no-build "$@" 2>&1 \
    | sed -nE 's/^.*Container ([^ ]+) +(Recreate|Create)d?.*$/\1/p' | sort -u
}

# Prints new version headings and bold lines added to CHANGELOG.md files.
changelog_highlights() { # repo_path from to
  git -C "$1" diff --unified=0 "$2" "$3" -- '*CHANGELOG.md' 2>/dev/null \
    | grep -E '^\+(## |.*\*\*)' | sed 's/^+/    /' || true
}

# Read-only Drupal checks. Prints findings, returns 1 when something is off.
prime_drupal_checks() {
  local out rc=0 themes extra=""
  if ! docker exec "$MANAGER_SVC" true 2>/dev/null; then
    log "  $MANAGER_SVC is not running, Drupal checks skipped."; return 1
  fi
  out="$(docker exec "$MANAGER_SVC" drush updatedb:status 2>&1 || true)"
  if grep -q 'No database updates required' <<<"$out"; then
    log "  ok    drush updatedb:status: no pending updates"
  else
    log "  FAIL  drush updatedb:status shows pending updates:"; sed 's/^/        /' <<<"$out" | head -20; rc=1
  fi
  if out="$(docker exec "$MANAGER_SVC" drush scs:check --problems 2>&1)"; then
    if [[ -n "${out//[[:space:]]/}" ]]; then log "  drush scs:check --problems:"; sed 's/^/        /' <<<"$out" | head -40; else log "  ok    drush scs:check --problems: nothing reported"; fi
  elif grep -qiE 'not defined|There are no commands' <<<"$out"; then
    log "  FAIL  drush scs:check does not exist in the running module (module too old or shadowed by a bind mount)"; rc=1
  else
    log "  FAIL  drush scs:check --problems:"; sed 's/^/        /' <<<"$out" | head -40; rc=1
  fi
  themes="$(docker exec "$MANAGER_SVC" drush pm:list --type=theme --status=enabled --format=json 2>/dev/null | jq -r 'keys[]' 2>/dev/null || true)"
  for t in $themes; do [[ "$ALLOWED_THEMES" == *" $t "* ]] || extra+=" $t"; done
  if [[ -z "$themes" ]]; then
    log "  FAIL  could not list the enabled themes"; rc=1
  elif [[ -n "$extra" ]]; then
    log "  FAIL  unexpected enabled theme(s):${extra} (expected only scs_custom_theme, gin and core themes)"; rc=1
  else
    log "  ok    enabled themes: $(tr '\n' ' ' <<<"$themes")"
  fi
  return $rc
}

prime_run() {
  local work; work="$(mktemp -d)"
  trap 'rm -rf "$CHANGED_FILES" "'"$work"'"' EXIT

  [[ -f .env ]] || { echo "No .env in ${REPO_ROOT}." >&2; exit 1; }
  local mgr_mode mgr_version
  mgr_mode="$(env_get SCS_MANAGER_MODE)"
  mgr_version="$(env_get SCS_MANAGER_IMAGE_VERSION)"

  log "Prime update, mode: ${MODE}"
  hr
  # ------------------------------------------------------------ 1. pre-checks
  log "Pre-checks:"
  if [[ "$mgr_mode" != production ]]; then
    echo "SCS_MANAGER_MODE is '${mgr_mode:-unset}', not 'production'. --prime is for the production host only." >&2
    exit 1
  fi
  log "  SCS_MANAGER_MODE=production"
  log "  SCS_MANAGER_IMAGE_VERSION=${mgr_version:-unset}$([[ "$mgr_version" == 3 ]] || echo "   (docs expect the major tag 3; a full version pins that release and no newer image is pulled)")"

  local dirty
  dirty="$(git status --porcelain --ignore-submodules=all --untracked-files=no | sed 's|^|deployment: |')"
  dirty+="$(git submodule foreach --quiet --recursive \
    'git status --porcelain --ignore-submodules=all --untracked-files=no | sed "s|^|$displaypath: |"' 2>/dev/null || true)"
  if [[ -n "${dirty//[[:space:]]/}" ]]; then
    BLOCKERS+=("uncommitted changes (nothing is reset; commit, stash or revert them yourself):"$'\n'"$(sed 's/^/      /' <<<"$dirty")")
    log "  uncommitted changes: YES"
  else
    log "  uncommitted changes: none"
  fi

  # ------------------------------------------------------------ 2. repos
  prime_net_setup
  local dep_from dep_to baseline
  dep_from="$(git rev-parse HEAD)"; dep_to="$dep_from"
  if [[ $OFFLINE -eq 0 ]] && ! "${GIT_NET[@]}" fetch --quiet --tags origin 2>/dev/null; then
    BLOCKERS+=("could not fetch the deployment repo (check network and GitHub access)")
  fi
  if git rev-parse -q --verify '@{u}' >/dev/null; then
    if git merge-base --is-ancestor HEAD '@{u}'; then
      dep_to="$(git rev-parse '@{u}')"
    elif ! git merge-base --is-ancestor '@{u}' HEAD; then
      BLOCKERS+=("deployment repo has diverged from $(git rev-parse --abbrev-ref '@{u}'); a fast-forward is not possible")
    fi
  fi

  # Baseline = deployment commit that was last applied on this host.
  baseline="$SINCE"
  [[ -n "$baseline" ]] || baseline="$(cat "$PRIME_STATE_FILE" 2>/dev/null || true)"
  [[ -n "$baseline" ]] || baseline="$dep_from"
  if ! baseline="$(git rev-parse -q --verify "${baseline}^{commit}")" || ! git merge-base --is-ancestor "$baseline" "$dep_to"; then
    warn "baseline is not an ancestor of the target, using the current HEAD instead"
    baseline="$dep_from"
  fi
  [[ "$baseline" == "$dep_to" ]] || record_changes . "$baseline" "$dep_to"

  log ""
  printf '%-28s %-10s %-10s %s\n' REPO FROM TO STATE
  local n
  if [[ "$dep_from" != "$dep_to" ]]; then
    n="$(git rev-list --count "${dep_from}..${dep_to}")"
    printf '%-28s %-10s %-10s %s\n' deployment "${dep_from:0:8}" "${dep_to:0:8}" "UPDATE (+${n})"
    PRIME_MOVES+=("deployment|.|$dep_from|$dep_to")
  else
    printf '%-28s %-10s %-10s %s\n' deployment "${dep_from:0:8}" "${dep_to:0:8}" "up-to-date"
  fi

  local name path url from ptr state
  while read -r key path; do
    name="${key#submodule.}"; name="${name%.path}"
    url="$(git config --blob "${dep_to}:.gitmodules" "submodule.${name}.url")"
    ptr="$(git ls-tree "$dep_to" -- "$path" | awk '{print $3}')"
    [[ -n "$ptr" ]] || continue
    if [[ ! -e "$path/.git" ]]; then
      printf '%-28s %-10s %-10s %s\n' "$name" "-" "${ptr:0:8}" "NEW (cloned on apply)"
      PRIME_MOVES+=("$name|$path||$ptr"); continue
    fi
    from="$(git -C "$path" rev-parse HEAD)"
    if [[ "$from" == "$ptr" ]]; then
      state="up-to-date"
    elif ! prime_have_commit "$path" "$ptr" "$url"; then
      state="BLOCKED: pointer commit not fetchable"
      BLOCKERS+=("$name: could not fetch the recorded commit ${ptr:0:8} (private repo without SSH access?)")
    elif git -C "$path" merge-base --is-ancestor "$from" "$ptr"; then
      state="UPDATE (+$(git -C "$path" rev-list --count "${from}..${ptr}"))"
      PRIME_MOVES+=("$name|$path|$from|$ptr")
      record_changes "$path" "$from" "$ptr"
    else
      state="BLOCKED: checkout is not behind the pointer"
      BLOCKERS+=("$name: the checkout (${from:0:8}) has commits the recorded pointer (${ptr:0:8}) lacks; following the pointer would move it backwards. Decide by hand.")
    fi
    printf '%-28s %-10s %-10s %s\n' "$name" "${from:0:8}" "${ptr:0:8}" "$state"
  done < <(git config --blob "${dep_to}:.gitmodules" --get-regexp '^submodule\..*\.path$')
  log "Baseline for deployment file changes: ${baseline:0:8} ($([[ -n "$SINCE" ]] && echo "--since" || { [[ -f "$PRIME_STATE_FILE" ]] && echo "last --prime --apply" || echo "current HEAD, no earlier --prime --apply recorded"; }))"
  hr

  local entry
  for entry in "${PRIME_MOVES[@]}"; do
    IFS='|' read -r name path from ptr <<<"$entry"
    [[ -n "$from" ]] || continue
    log "## $name"
    git -C "$path" log --oneline --no-decorate -n 15 "${from}..${ptr}"
    log ""
  done

  # ------------------------------------------------------------ 3. derived files
  log "Override copies (source in 00_custom_configs -> gitignored copy in the stack):"
  local pair src dst
  for pair in "${DERIVED_OVERRIDES[@]}"; do
    src="${pair%%|*}"; dst="${pair##*|}"
    if git diff --quiet "$baseline" "$dep_to" -- "$src"; then
      if git show "${dep_to}:${src}" 2>/dev/null | cmp -s - "$dst"; then
        log "  unchanged   $dst"
      else
        log "  unchanged   $dst   (copy differs from the source: local Prime edits, left alone)"
      fi
    elif [[ ! -e "$dst" ]] || git show "${baseline}:${src}" 2>/dev/null | cmp -s - "$dst"; then
      log "  COPY        $src -> $dst"
      COPY_NOW+=("$pair")
    else
      log "  MANUAL      $src changed, but $dst has local edits and is not overwritten"
      TODOS+=("Merge the changed override by hand: diff $dst $src")
    fi
  done

  log "Systemd units (01_scripts/global -> ${SYSTEMD_DIR}):"
  local unit base verb units_changed=() timers=()
  while read -r unit; do
    base="$(basename "$unit")"
    if [[ ! -f "${SYSTEMD_DIR}/${base}" ]]; then
      log "  NOT INSTALLED  $base"; units_changed+=("$base")
    elif git show "${dep_to}:${unit}" | cmp -s - "${SYSTEMD_DIR}/${base}"; then
      log "  same           $base"
    else
      log "  DIFFERS        $base"; units_changed+=("$base")
    fi
  done < <(git ls-tree --name-only "$dep_to" 01_scripts/global/ | grep -E '\.(service|timer)$')
  if [[ ${#units_changed[@]} -gt 0 ]]; then
    for base in "${units_changed[@]}"; do
      UNIT_CMDS+=("cp ${REPO_ROOT}/01_scripts/global/${base} ${SYSTEMD_DIR}/")
      # A changed service is started by the timer of the same name, if there is one.
      if [[ "$base" == *.timer ]]; then
        timers+=("$base")
      elif git cat-file -e "${dep_to}:01_scripts/global/${base%.*}.timer" 2>/dev/null; then
        timers+=("${base%.*}.timer")
      else
        TODOS+=("${base} changed and has no timer: after installing it, decide whether to restart it (sudo systemctl restart ${base}).")
      fi
    done
    UNIT_CMDS+=("systemctl daemon-reload")
    while read -r base; do
      verb="restart"; systemctl is-enabled --quiet "$base" 2>/dev/null || verb="enable --now"
      UNIT_CMDS+=("systemctl ${verb} ${base}")
    done < <(printf '%s\n' "${timers[@]}" | sort -u)
  fi

  # ------------------------------------------------------------ plan: services
  compute_impact
  local -a running=() others=() recreate=() drift=() tagchg=()
  mapfile -t running < <(docker compose ps --services --status running 2>/dev/null)
  mapfile -t others < <(printf '%s\n' "${running[@]}" | grep -vx "$MANAGER_SVC" || true)
  mapfile -t recreate < <(printf '%s\n' "${REBUILD[@]}" "${RESTART[@]}" | grep -v '^$' | sort -u)
  mapfile -t drift < <(compose_recreate_preview "${running[@]}")
  mapfile -t tagchg < <(image_tag_changes)
  local nc_change; nc_change="$(printf '%s\n' "${tagchg[@]}" | awk -F '\t' -v s="$NEXTCLOUD_SVC" '$1 == s {print $2 " -> " $3}')"
  local shadow; shadow="$(manager_shadow_binds)"

  hr
  log "Planned actions:"
  log "  build                         : ${REBUILD[*]:-(none)}"
  log "  recreate (build or bind files): ${recreate[*]:-(none)}"
  log "  recreate (compose/.env drift) : ${drift[*]:-(none)}"
  if [[ ${#tagchg[@]} -gt 0 ]]; then
    log "  image tags that change:"; printf '      %s\n' "${tagchg[@]}" | sed 's/\t/  /g'
  else
    log "  image tags that change        : (none)"
  fi
  [[ "$dep_from" == "$dep_to" ]] || log "  note: the deployment repo moves, so the lines above come from the compose files before the pull."
  if [[ -n "$shadow" ]]; then
    log "  SCS Manager image             : SKIPPED, the container bind-mounts module or theme over the image:"
    sed 's/^/      /' <<<"$shadow"
    TODOS+=("SCS Manager not updated: $MANAGER_SVC bind-mounts the module/theme, which hides the copies in the image. Remove those mounts from scs-manager-stack/docker-compose.override.yml (see dev-to-prime, path B step 5), then run --prime --apply again.")
  else
    log "  SCS Manager image             : docker compose pull $MANAGER_SVC, up -d, follow the log"
  fi
  log "  DB snapshot before restarts   : $([[ $SNAPSHOT -eq 1 ]] && echo "${PRIME_BACKUP_ROOT}/<timestamp>/all-databases.sql.gz (only if a container is recreated)" || echo "off (--no-snapshot)")"
  if [[ -n "$nc_change" ]]; then
    log "  Nextcloud version change      : ${nc_change} -> backup-nextcloud.bash runs first"
    TODOS+=("Nextcloud changed version (${nc_change}): run 01_scripts/scs-nextcloud-stack/run-nextcloud-repair.bash, then 'occ app:update --all' (docs: maintenance/updates.md, Nextcloud).")
  fi
  if [[ ${#UNIT_CMDS[@]} -gt 0 ]]; then
    log "  systemd (needs root)          :"; printf '      sudo %s\n' "${UNIT_CMDS[@]}"
  fi
  if [[ $SNAPSHOT -eq 1 ]]; then
    local db_container db_pw
    db_container="$(env_get SCS_CONTAINER_DATABASE)"; db_container="${db_container:-core--mariadb--db}"
    db_pw="$(env_get SCS_DB_ROOT_PASSWORD)"
    if ! docker exec -e MYSQL_PWD="$db_pw" "$db_container" mariadb -uroot -e 'SELECT 1' >/dev/null 2>&1; then
      BLOCKERS+=("database $db_container does not accept the root login from .env, so no snapshot is possible (or pass --no-snapshot)")
    fi
    local probe="$PRIME_BACKUP_ROOT"
    while [[ ! -e "$probe" ]]; do probe="$(dirname "$probe")"; done
    if [[ ! -d "$probe" || ! -w "$probe" ]]; then
      BLOCKERS+=("snapshot directory $PRIME_BACKUP_ROOT is not writable (set SCS_UPDATE_BACKUP_DIR or pass --no-snapshot)")
    fi
  fi

  local hl printed=0
  for entry in "${PRIME_MOVES[@]}"; do
    IFS='|' read -r name path from ptr <<<"$entry"
    [[ -n "$from" ]] || continue
    hl="$(changelog_highlights "$path" "$from" "$ptr")"
    [[ -n "$hl" ]] || continue
    [[ $printed -eq 1 ]] || { hr; log "New changelog sections and bold (manual) steps:"; printed=1; }
    log "  $name:"; log "$hl"
    grep -q '\*\*' <<<"$hl" && TODOS+=("$name CHANGELOG has bold manual steps, see above.")
  done

  if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
    hr
    log "BLOCKED, nothing will be applied until this is resolved:"
    printf '  - %s\n' "${BLOCKERS[@]}"
  fi

  if [[ "$MODE" == check ]]; then
    hr
    log "State of the SCS Manager right now (the same checks run after --apply):"
    prime_drupal_checks || true
    if [[ ${#TODOS[@]} -gt 0 ]]; then hr; log "Manual steps that will remain:"; printf '  [ ] %s\n' "${TODOS[@]}"; fi
    hr
    log "Check only, nothing was changed. Run with --prime --apply to execute."
    [[ ${#BLOCKERS[@]} -eq 0 ]] || exit 1
    exit 0
  fi

  # ============================================================== apply
  [[ ${#BLOCKERS[@]} -eq 0 ]] || exit 1
  hr
  local failed=0

  if [[ "$dep_from" != "$dep_to" ]]; then
    log "Fast-forwarding the deployment repo to ${dep_to:0:8}"
    git merge --ff-only --quiet "$dep_to"
  fi
  log "Checking out the recorded submodule commits"
  git submodule sync --quiet --recursive
  "${GIT_NET[@]}" submodule update --init --recursive

  for pair in "${COPY_NOW[@]}"; do
    src="${pair%%|*}"; dst="${pair##*|}"
    log "Copying $src -> $dst"
    cp "$src" "$dst"
  done

  if [[ ${#UNIT_CMDS[@]} -gt 0 ]]; then
    if [[ $EUID -eq 0 ]]; then
      local cmd
      for cmd in "${UNIT_CMDS[@]}"; do log "Running: $cmd"; $cmd; done
    else
      TODOS+=("Install the changed systemd units (needs root):"$'\n'"$(printf '        sudo %s\n' "${UNIT_CMDS[@]}")")
    fi
  fi

  # Compose files may have changed with the pull: plan again from the new state.
  compute_impact
  shadow="$(manager_shadow_binds)"
  mapfile -t recreate < <(printf '%s\n' "${REBUILD[@]}" "${RESTART[@]}" | grep -v '^$' | sort -u)
  if [[ ${#REBUILD[@]} -gt 0 ]]; then
    log "Building: ${REBUILD[*]}"
    docker compose build "${REBUILD[@]}"
  fi

  local mgr_image_before mgr_image_after=""
  mgr_image_before="$(docker inspect "$MANAGER_SVC" --format '{{.Image}}' 2>/dev/null || true)"
  if [[ -z "$shadow" ]]; then
    log "Pulling the SCS Manager image"
    docker compose pull --quiet "$MANAGER_SVC" || { warn "pull of $MANAGER_SVC failed"; failed=1; }
    mgr_image_after="$(docker image inspect "$(jq -r --arg s "$MANAGER_SVC" '.services[$s].image' <<<"$COMPOSE_JSON")" --format '{{.Id}}' 2>/dev/null || true)"
  fi

  mapfile -t drift < <(compose_recreate_preview "${running[@]}")
  mapfile -t tagchg < <(image_tag_changes)
  nc_change="$(printf '%s\n' "${tagchg[@]}" | awk -F '\t' -v s="$NEXTCLOUD_SVC" '$1 == s {print $2 " -> " $3}')"
  local touches=0
  [[ ${#recreate[@]} -eq 0 && ${#drift[@]} -eq 0 ]] || touches=1
  [[ -z "$mgr_image_after" || "$mgr_image_after" == "$mgr_image_before" ]] || touches=1

  if [[ $touches -eq 1 && $SNAPSHOT -eq 1 ]]; then
    local snap_dir snap
    snap_dir="${PRIME_BACKUP_ROOT}/$(date +%Y%m%d_%H%M%S)"; snap="${snap_dir}/all-databases.sql.gz"
    mkdir -p "$snap_dir"
    log "Snapshot of all databases -> $snap"
    if ! docker exec -e MYSQL_PWD="$db_pw" "$db_container" \
         mariadb-dump -uroot --all-databases --single-transaction --quick --routines --events | gzip >"$snap" \
       || [[ "$(stat -c %s "$snap")" -lt 1024 ]]; then
      echo "Database snapshot failed, stopping before any container is touched." >&2
      exit 1
    fi
    log "  $(du -h "$snap" | cut -f1) written"
    if [[ -n "$nc_change" ]]; then
      log "Nextcloud changes version (${nc_change}): running backup-nextcloud.bash"
      bash 01_scripts/scs-nextcloud-stack/backup-nextcloud.bash || { echo "Nextcloud backup failed, stopping before any container is touched." >&2; exit 1; }
    fi
  elif [[ $touches -eq 0 ]]; then
    log "No container needs to be recreated, snapshot skipped."
  fi

  declare -A before=()
  local svc id
  while IFS=$'\t' read -r svc id; do before["$svc"]="$id"; done \
    < <(docker compose ps -a --format '{{.Service}}\t{{.ID}}' 2>/dev/null)

  if [[ ${#others[@]} -gt 0 ]]; then
    log "Recreating changed services"
    docker compose up -d --no-build "${others[@]}" || failed=1
  fi
  for svc in "${recreate[@]}"; do
    [[ "$svc" != "$MANAGER_SVC" && " ${running[*]} " == *" $svc "* ]] || continue
    docker compose up -d --no-build --no-deps --force-recreate "$svc" || failed=1
  done

  # ------------------------------------------------------------ SCS Manager
  if [[ " ${running[*]} " == *" $MANAGER_SVC "* ]]; then
    local since log_pid="" waited=0 st clog_before="${work}/changelog.before"
    docker exec "$MANAGER_SVC" cat "$MANAGER_CHANGELOG" >"$clog_before" 2>/dev/null || true
    since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ " ${recreate[*]} " == *" $MANAGER_SVC "* ]]; then
      docker compose up -d --no-build --no-deps --force-recreate "$MANAGER_SVC" || failed=1
    else
      docker compose up -d --no-build --no-deps "$MANAGER_SVC" || failed=1
    fi
    if [[ "$(docker compose ps -a -q "$MANAGER_SVC")" != "${before[$MANAGER_SVC]:-}"* ]]; then
      log "SCS Manager was recreated, following its log until it is up (max ${MANAGER_WAIT_SECONDS}s)"
      docker compose logs -f --no-log-prefix --since "$since" "$MANAGER_SVC" 2>&1 | sed 's/^/    | /' &
      log_pid=$!
      while (( waited < MANAGER_WAIT_SECONDS )); do
        st="$(docker inspect "$MANAGER_SVC" --format '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || echo gone)"
        case "$st" in
          running/healthy) break ;;
          running/none) docker compose logs --since "$since" "$MANAGER_SVC" 2>&1 | grep -q 'ready to handle connections' && break ;;
          running/*) ;;
          *) warn "SCS Manager is ${st}"; failed=1; break ;;
        esac
        sleep 5; waited=$((waited + 5))
      done
      kill "$log_pid" 2>/dev/null || true; wait "$log_pid" 2>/dev/null || true
      (( waited < MANAGER_WAIT_SECONDS )) || { warn "SCS Manager did not become healthy in ${MANAGER_WAIT_SECONDS}s"; failed=1; }
      hr
      log "SCS Manager start, lines to look at:"
      local marks
      marks="$(docker compose logs --no-log-prefix --since "$since" "$MANAGER_SVC" 2>&1 | grep -E 'Package set changed|Shipped content changed|ERROR:' || true)"
      if [[ -n "$marks" ]]; then
        sed 's/^/    /' <<<"$marks"
        grep -q 'ERROR:' <<<"$marks" && { failed=1; TODOS+=("The SCS Manager start logged ERROR: lines (above). That step runs again on the next 'docker compose up -d $MANAGER_SVC'."); }
      else
        log "    neither 'Package set changed' nor 'Shipped content changed': both fingerprints were unchanged."
      fi
      if docker exec "$MANAGER_SVC" cat "$MANAGER_CHANGELOG" >"${work}/changelog.after" 2>/dev/null; then
        hl="$(diff "$clog_before" "${work}/changelog.after" | grep -E '^> (## |.*\*\*)' | sed 's/^> /    /' || true)"
        if [[ -n "$hl" ]]; then
          log "soda_scs_manager CHANGELOG, new sections and bold (manual) steps:"; log "$hl"
          grep -q '\*\*' <<<"$hl" && TODOS+=("soda_scs_manager CHANGELOG has bold manual steps, see above.")
        fi
      fi
    else
      log "SCS Manager: no new image and no config change, container left as it is."
    fi
  fi

  # ------------------------------------------------------------ verify
  hr
  log "Verification:"
  local -a recreated=()
  while IFS=$'\t' read -r svc id; do
    [[ -n "${before[$svc]:-}" && "${before[$svc]}" != "$id" ]] && recreated+=("$svc")
  done < <(docker compose ps -a --format '{{.Service}}\t{{.ID}}' 2>/dev/null)
  log "  recreated: ${recreated[*]:-(none)}"
  local problems
  problems="$(docker compose ps -a --format '{{.Service}}\t{{.Status}}' | grep -E 'unhealthy|Restarting|Exited|Dead' || true)"
  if [[ -n "$problems" ]]; then
    log "  FAIL  services needing attention:"; sed 's/^/        /' <<<"$problems"; failed=1
  else
    log "  ok    no service is unhealthy, restarting or exited"
  fi
  prime_drupal_checks || failed=1

  hr
  if [[ ${#TODOS[@]} -gt 0 ]]; then
    log "Manual steps left for you:"
    printf '  [ ] %s\n' "${TODOS[@]}"
  else
    log "No manual steps left."
  fi
  if [[ $failed -eq 0 ]]; then
    git rev-parse HEAD >"$PRIME_STATE_FILE"
    log "Done."
  else
    log "Finished WITH PROBLEMS, see FAIL/WARN lines above. Logs: docker compose logs --tail 100 <service>"
    exit 1
  fi
}

if [[ $PRIME -eq 1 ]]; then
  prime_run
  exit 0
fi

# ---------------------------------------------------------------- planning
log "Fetching remotes..."
hr

if [[ $SKIP_DEPLOYMENT -eq 0 ]]; then
  dep_state=ok
  [[ $OFFLINE -eq 1 ]] || git fetch --quiet --tags --prune 2>/dev/null || dep_state=fetch-failed
  [[ -z "$(git status --porcelain --ignore-submodules=all --untracked-files=no)" ]] || dep_state=dirty
  dep_from="$(git rev-parse HEAD)"
  if [[ "$dep_state" == fetch-failed ]]; then
    dep_to="$dep_from"
  elif git rev-parse -q --verify '@{u}' >/dev/null; then
    dep_to="$(git rev-parse '@{u}')"
    if ! git merge-base --is-ancestor HEAD '@{u}'; then
      git merge-base --is-ancestor '@{u}' HEAD && dep_to="$dep_from" || dep_state=diverged
    fi
  else
    dep_to="$dep_from"; dep_state=no-upstream
  fi
  PLAN+=("deployment|.|branch|$dep_from|$dep_to|@{u}|$dep_state")
fi

mapfile -t SUBMODULES < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

for path in "${SUBMODULES[@]}"; do
  name="$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk -v p="$path" '$2==p{sub(/^submodule\./,"",$1); sub(/\.path$/,"",$1); print $1}')"
  if [[ -n "$ONLY" && ",$ONLY," != *",$path,"* && ",$ONLY," != *",$name,"* ]]; then continue; fi

  if [[ ! -e "$path/.git" ]]; then
    PLAN+=("$name|$path|-|-|-|-|uninitialized"); continue
  fi

  if [[ $OFFLINE -eq 0 ]] && ! git -C "$path" fetch --quiet --all --tags --prune 2>/dev/null; then
    PLAN+=("$name|$path|-|-|-|-|fetch-failed"); continue
  fi

  state=ok
  [[ -z "$(git -C "$path" status --porcelain --untracked-files=no)" ]] || state=dirty
  from="$(git -C "$path" rev-parse HEAD)"

  track="$(git config -f .gitmodules "submodule.${name}.scs-track" || true)"
  if [[ -z "$track" ]]; then
    if git -C "$path" describe --tags --exact-match HEAD 2>/dev/null | grep -qE "$SEMVER_RE"; then
      track=release
    else
      track=branch
    fi
  fi

  if [[ "$track" == release ]]; then
    ref="$(newest_semver_tag "$path")"
    if [[ -z "$ref" ]]; then
      to="$from"; state=no-tags
    else
      to="$(git -C "$path" rev-parse "${ref}^{commit}")"
      cur="$(git -C "$path" describe --tags --exact-match HEAD 2>/dev/null || true)"
      # never downgrade
      if [[ -n "$cur" && "$(printf '%s\n%s\n' "$cur" "$ref" | sort -V | tail -1)" != "$ref" ]]; then to="$from"; fi
    fi
  else
    b="$(follow_branch "$path" "$name")"
    # prefer the branch's configured upstream (e.g. a fork remote), else origin/<branch>
    ref="$(git -C "$path" rev-parse -q --abbrev-ref --symbolic-full-name "${b}@{upstream}" 2>/dev/null || true)"
    [[ -n "$ref" ]] || ref="origin/$b"
    if ! git -C "$path" rev-parse -q --verify "$ref" >/dev/null; then
      to="$from"; state=no-remote-branch
    else
      to="$(git -C "$path" rev-parse "$ref")"
      if ! git -C "$path" merge-base --is-ancestor HEAD "$ref"; then
        if git -C "$path" merge-base --is-ancestor "$ref" HEAD; then to="$from"; else state=diverged; fi
      fi
    fi
  fi
  PLAN+=("$name|$path|$track|$from|$to|$ref|$state")
done

# ---------------------------------------------------------------- report
printf '%-28s %-8s %-18s %-10s %-10s %s\n' REPO MODE TARGET FROM TO STATE
updates=0
for entry in "${PLAN[@]}"; do
  IFS='|' read -r name path track from to ref state <<<"$entry"
  marker=""
  if [[ "$state" == ok && "$from" != "$to" ]]; then
    n="$(git -C "$path" rev-list --count "${from}..${to}" 2>/dev/null || echo '?')"
    marker="UPDATE (+${n})"; updates=$((updates+1))
    record_changes "$path" "$from" "$to"
  elif [[ "$state" == ok ]]; then
    marker="up-to-date"
  else
    marker="SKIP: ${state}"
  fi
  printf '%-28s %-8s %-18s %-10s %-10s %s\n' "$name" "$track" "$ref" "${from:0:8}" "${to:0:8}" "$marker"
done
hr

for entry in "${PLAN[@]}"; do
  IFS='|' read -r name path track from to ref state <<<"$entry"
  [[ "$state" == ok && "$from" != "$to" ]] || continue
  log "## $name ($path)"
  git -C "$path" log --oneline --no-decorate -n 15 "${from}..${to}"
  log ""
done

# ---------------------------------------------------------------- service impact
compute_impact
compose_changed="$(grep -cE '(docker-compose|compose)[^/]*\.ya?ml$' "$CHANGED_FILES" || true)"

log "Planned actions:"
log "  rebuild + recreate : ${REBUILD[*]:-(none)}"
log "  restart (bind cfg) : ${RESTART[*]:-(none)}"
log "  compose files changed: ${compose_changed:-0}"
[[ $PULL_IMAGES -eq 1 ]] && log "  pull image-only services, recreate those with new image IDs"
hr

if [[ "$MODE" == check ]]; then
  log "Check only. ${updates} repo(s) have updates. Run with --apply to execute."
  exit 0
fi

# ---------------------------------------------------------------- apply
for entry in "${PLAN[@]}"; do
  IFS='|' read -r name path track from to ref state <<<"$entry"
  [[ "$state" == ok && "$from" != "$to" ]] || continue
  log "Updating $name -> ${ref} (${to:0:8})"
  if [[ "$path" == "." ]]; then
    git merge --ff-only --quiet '@{u}'
    # initialise submodules newly added upstream, leave existing ones alone
    git submodule sync --quiet
    while read -r sm_path; do
      git submodule update --init --recursive -- "$sm_path"
    done < <(git submodule status | awk '/^-/{print $2}')
  elif [[ "$track" == release ]]; then
    git -C "$path" -c advice.detachedHead=false checkout --quiet "$ref"
  else
    b="${ref#*/}"
    if [[ -z "$(git -C "$path" branch --show-current)" ]]; then
      git -C "$path" checkout --quiet -B "$b" --track "$ref" 2>/dev/null || git -C "$path" checkout --quiet "$b"
    fi
    git -C "$path" merge --ff-only --quiet "$ref"
  fi
  [[ "$path" == "." ]] || git -C "$path" submodule update --init --recursive --quiet
done

declare -A BEFORE=()
while IFS=$'\t' read -r svc id; do BEFORE["$svc"]="$id"; done \
  < <(docker compose ps -a --format '{{.Service}}\t{{.ID}}' 2>/dev/null)
mapfile -t RUNNING < <(docker compose ps --services --status running 2>/dev/null)

if [[ $PULL_IMAGES -eq 1 ]]; then
  log "Pulling images..."
  docker compose pull --ignore-buildable --ignore-pull-failures --quiet "${RUNNING[@]}" || warn "image pull had errors"
fi

if [[ ${#REBUILD[@]} -gt 0 ]]; then
  log "Building: ${REBUILD[*]}"
  docker compose build "${REBUILD[@]}"
fi

# Recreate everything that is running; compose only touches services whose
# config hash or image changed. Explicitly force rebuilt services.
if [[ ${#RUNNING[@]} -gt 0 ]]; then
  log "Recreating changed services..."
  docker compose up -d --no-build "${RUNNING[@]}"
fi
for svc in "${REBUILD[@]}"; do
  if [[ " ${RUNNING[*]} " == *" $svc "* ]]; then
    docker compose up -d --no-build --no-deps --force-recreate "$svc"
  fi
done

declare -a RECREATED=()
while IFS=$'\t' read -r svc id; do
  [[ -n "${BEFORE[$svc]:-}" && "${BEFORE[$svc]}" != "$id" ]] && RECREATED+=("$svc")
done < <(docker compose ps -a --format '{{.Service}}\t{{.ID}}' 2>/dev/null)

for svc in "${RESTART[@]}"; do
  [[ " ${RECREATED[*]} " == *" $svc "* ]] && continue
  [[ " ${RUNNING[*]} " == *" $svc "* ]] || continue
  log "Restarting $svc (bind-mounted config changed)"
  docker compose restart "$svc"
done

hr
log "Recreated: ${RECREATED[*]:-(none)}"
mapfile -t NOT_RUNNING < <(comm -23 <(jq -r '.services | keys[]' <<<"$COMPOSE_JSON" | sort) <(docker compose ps --services --status running | sort))
[[ ${#NOT_RUNNING[@]} -eq 0 ]] || log "Defined but not running (left untouched): ${NOT_RUNNING[*]}"
problems="$(docker compose ps -a --format '{{.Service}}\t{{.Status}}' | grep -E 'unhealthy|Restarting|Exited|Dead' || true)"
[[ -z "$problems" ]] || { warn "services needing attention:"; printf '%s\n' "$problems" >&2; }
if ! git diff --quiet --ignore-submodules=none -- "${SUBMODULES[@]}"; then
  log ""
  log "Submodule pointers moved in the deployment repo (not committed):"
  git submodule status | grep '^+' || true
fi
log "Done."
