#!/usr/bin/env bash
# Push everything the scs-release-prep skill prepared, in one go.
#
# The skill commits and tags locally and writes the push plan to
# plans/push-plan.txt (gitignored). This script loads the SSH key into an
# agent once (one passphrase prompt) and runs the plan top to bottom.
#
# Plan format, one action per line, lines starting with '#' are comments:
#   push <repo-path> <remote> <refspec>...   git push, path relative to the deployment root
#   show <file>                              print a file (e.g. release notes to paste), path relative to the deployment root
#   pause <text>                             print a manual step, wait for Enter
#   wait-drupal <project> <version>          wait until drupal.org lists the release
#   note <text>                              print a reminder now
#   todo <text>                              manual step after the run, listed at the end
#
# Usage:
#   01_scripts/global/push-release-plan.bash            # run plans/push-plan.txt
#   01_scripts/global/push-release-plan.bash --dry-run  # show what would be pushed
#   01_scripts/global/push-release-plan.bash path/to/plan.txt
#
# --dry-run works offline from the last fetched remote state, no passphrase.
# Re-running is safe: refs that are already on the remote are up to date.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN="${ROOT}/plans/push-plan.txt"
DRY_RUN=0
MISSING=0
TODOS=()
WAIT_TIMEOUT="${WAIT_TIMEOUT:-3600}"
WAIT_INTERVAL=30

for arg in "$@"; do
  case "${arg}" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) PLAN="${arg}" ;;
  esac
done

[[ -f "${PLAN}" ]] || { echo "No plan at ${PLAN}. Run the scs-release-prep skill first." >&2; exit 1; }

ensure_agent() {
  local rc=0
  ssh-add -l >/dev/null 2>&1 || rc=$?
  (( rc == 0 )) && return 0
  if (( rc == 2 )); then
    eval "$(ssh-agent -s)" >/dev/null
    trap 'ssh-agent -k >/dev/null 2>&1 || true' EXIT
  fi
  echo "Loading the SSH key once for all pushes:"
  ssh-add
}

# Push GitHub https remotes over SSH too, so one key covers every repo.
GIT_PUSH=(git -c 'url.git@github.com:.pushInsteadOf=https://github.com/')

do_push() {
  local path="$1" remote="$2"; shift 2
  local dir="${ROOT}/${path}"
  [[ "${path}" == "." ]] && dir="${ROOT}"
  [[ -d "${dir}" ]] && git -C "${dir}" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "Not a git repo: ${path}" >&2; return 1; }
  if [[ -n "$(git -C "${dir}" status --porcelain --ignore-submodules=dirty)" ]]; then
    echo "WARN ${path} has uncommitted changes; pushing committed state only." >&2
  fi
  echo "==> ${path}: git push ${remote} $*"
  if (( DRY_RUN )); then
    dry_run_ref "${dir}" "${remote}" "$@"
  else
    "${GIT_PUSH[@]}" -C "${dir}" push "${remote}" "$@"
  fi
}

# Offline preview: compare local refs with the last fetched remote state.
dry_run_ref() {
  local dir="$1" remote="$2"; shift 2
  local ref src
  for ref in "$@"; do
    src="${ref%%:*}"
    if git -C "${dir}" show-ref --verify -q "refs/tags/${src}"; then
      echo "    tag ${src} -> $(git -C "${dir}" rev-list -n1 "${src}" | cut -c1-9)"
    elif git -C "${dir}" show-ref --verify -q "refs/heads/${src}"; then
      if git -C "${dir}" show-ref --verify -q "refs/remotes/${remote}/${src}"; then
        echo "    branch ${src}: $(git -C "${dir}" rev-list --count "${remote}/${src}..${src}") commit(s) ahead of ${remote}/${src}"
        git -C "${dir}" log --oneline "${remote}/${src}..${src}" | sed 's/^/      /'
      else
        echo "    branch ${src}: new on ${remote}"
      fi
    else
      echo "    MISSING local ref ${src}" >&2
      MISSING=$(( MISSING + 1 ))
    fi
  done
}

do_wait_drupal() {
  local project="$1" version="$2" waited=0
  local url="https://updates.drupal.org/release-history/${project}/current"
  echo "==> waiting for ${project} ${version} on drupal.org"
  echo "    Create the release node if needed: https://www.drupal.org/project/${project}/releases"
  (( DRY_RUN )) && return 0
  until curl -fsS "${url}" 2>/dev/null | grep -q "<version>${version}</version>"; do
    if (( waited >= WAIT_TIMEOUT )); then
      echo "Release ${version} is not on drupal.org after ${WAIT_TIMEOUT}s. Re-run this script once it is." >&2
      return 1
    fi
    sleep "${WAIT_INTERVAL}"; waited=$(( waited + WAIT_INTERVAL ))
    printf '    still waiting (%ss)\n' "${waited}"
  done
  echo "    ${project} ${version} is published."
}

(( DRY_RUN )) || ensure_agent

lineno=0
while IFS= read -r line || [[ -n "${line}" ]]; do
  lineno=$(( lineno + 1 ))
  [[ "${line}" =~ ^[[:space:]]*# ]] && continue
  read -r -a words <<<"${line}"
  (( ${#words[@]} )) || continue
  case "${words[0]}" in
    push)
      (( ${#words[@]} >= 4 )) || { echo "Line ${lineno}: push <path> <remote> <refspec>..." >&2; exit 1; }
      do_push "${words[@]:1}" ;;
    wait-drupal)
      (( ${#words[@]} == 3 )) || { echo "Line ${lineno}: wait-drupal <project> <version>" >&2; exit 1; }
      do_wait_drupal "${words[1]}" "${words[2]}" ;;
    note)
      echo "NOTE ${line#*note }" ;;
    todo)
      TODOS+=("${line#*todo }") ;;
    show)
      (( ${#words[@]} == 2 )) || { echo "Line ${lineno}: show <file>" >&2; exit 1; }
      [[ -f "${ROOT}/${words[1]}" ]] || { echo "Line ${lineno}: no such file ${words[1]}" >&2; exit 1; }
      echo "==> ${words[1]}"
      echo "------------------------------------------------------------------------"
      cat "${ROOT}/${words[1]}"
      echo "------------------------------------------------------------------------" ;;
    pause)
      echo "==> MANUAL STEP: ${line#*pause }"
      (( DRY_RUN )) || read -r -p "    Press Enter when done (Ctrl-C to stop; re-running is safe) " </dev/tty ;;
    *)
      echo "Line ${lineno}: unknown action '${words[0]}'" >&2; exit 1 ;;
  esac
done <"${PLAN}"

if (( ${#TODOS[@]} )); then
  echo
  echo "Still to do by hand:"
  printf '  [ ] %s\n' "${TODOS[@]}"
  echo
fi

if (( DRY_RUN )); then
  (( MISSING == 0 )) || { echo "Dry run found ${MISSING} missing ref(s)." >&2; exit 1; }
  echo "Dry run done. Nothing was pushed."
else
  mv "${PLAN}" "${PLAN%.txt}.done-$(date +%Y%m%d-%H%M%S).txt"
  echo "All pushes done. The plan was archived next to ${PLAN}."
fi
