#!/usr/bin/env bash
# Keep Drupal custom code editable by all www-data group members.
#
# Problem: host editors (Cursor, vim, …) rewrite files as the current user
# (e.g. rnsrk:rnsrk). Other developers then cannot write those files.
#
# Fix: force group www-data, setgid on directories, group-writable mode, and
# default ACLs so new/replaced files stay group-writable for www-data.
#
# Usage (from anywhere, needs root):
#   sudo bash /var/www/deploy/soda_scs_manager_deployment/01_scripts/scs-manager-stack/fix-www-data-shared-edit.bash
#   sudo bash …/fix-www-data-shared-edit.bash /path/to/dir

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 ${*:-}" >&2
  exit 1
fi

DEFAULT_PATHS=(
  /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/modules/custom/soda_scs_manager
  /var/www/deploy/soda_scs_manager_deployment/scs-manager-stack/volumes/drupal-root/web/themes/custom/scs_custom_theme
)

PATHS=("${@:-${DEFAULT_PATHS[@]}}")

for target in "${PATHS[@]}"; do
  if [[ ! -d "${target}" ]]; then
    echo "Skip (missing): ${target}"
    continue
  fi

  echo "=== Fixing shared edit perms: ${target}"

  # Owner/group back to www-data (owner may flip again on next editor save;
  # group + setgid + ACL keep teammates able to write).
  chown -R www-data:www-data "${target}"

  # Directories: rwx for user/group, setgid so new files inherit group www-data.
  find "${target}" -type d -exec chmod 2775 {} +

  # Files: group-writable; capital X keeps execute only where it already is.
  find "${target}" -type f -exec chmod ug+rwX,o+rX {} +

  # Access ACL now + default ACL for future creates/renames.
  # Default ACLs still grant www-data write even if a tool drops setgid/group.
  setfacl -R -m "u::rwx,g:www-data:rwx,o::r-x" "${target}"
  setfacl -R -d -m "u::rwx,g:www-data:rwx,o::r-x" "${target}"

  # Shared git: new index/objects stay group-writable for www-data.
  # Write the config file directly — `git -C` as root often fails on
  # safe.directory / ownership checks ("not in a git directory").
  if [[ -f "${target}/.git/config" ]]; then
    git config --file "${target}/.git/config" core.sharedRepository group
    echo "git core.sharedRepository=group"
  elif [[ -d "${target}/.git" ]]; then
    echo "Skip git config (no .git/config): ${target}"
  fi

  echo "Done: ${target}"
done

echo
echo "All developers must be in group www-data:"
getent group www-data
echo
echo "Recommended shell umask for shared trees: umask 002"
echo "Re-run this script after bulk copies/checkouts if ownership drifts."
