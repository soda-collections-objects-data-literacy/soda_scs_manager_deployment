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
SEMVER_RE='^v?[0-9]+\.[0-9]+\.[0-9]+$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE=check ;;
    --apply) MODE=apply ;;
    --no-images) PULL_IMAGES=0 ;;
    --only) ONLY="$2"; shift ;;
    --skip-deployment) SKIP_DEPLOYMENT=1 ;;
    --offline) OFFLINE=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
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
