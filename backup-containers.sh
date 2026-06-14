#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") -r <repo_path> [-d <dest_path>]"
  echo "  -r  Path to deployment repository (required)"
  echo "  -d  Destination for backup tarball (default: ./backup-<timestamp>.tar.gz)"
  exit 1
}

repo_path=""
dest_path=""

while getopts "r:d:h" opt; do
  case "$opt" in
    r) repo_path="$OPTARG" ;;
    d) dest_path="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

[ -z "$repo_path" ] && usage
[ -d "$repo_path" ] || { echo "Error: -r must be an existing directory" >&2; exit 1; }
repo_path="$(cd "$repo_path" && pwd)"

[ -z "$dest_path" ] && dest_path="./backup-$(date +%Y%m%d-%H%M%S).tar.gz"
if [ -d "$dest_path" ]; then
  dest_path="${dest_path%/}/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
fi
dest_dir="$(dirname "$dest_path")"
[ -d "$dest_dir" ] || mkdir -p "$dest_dir"

[ "$EUID" -eq 0 ] || echo "Warning: not running as root -- may fail to read volumes" >&2

docker info >/dev/null 2>&1 || { echo "Error: Docker is not running" >&2; exit 1; }

docker_root=$(docker info -f '{{.DockerRootDir}}')
volumes_dir="${docker_root%/}/volumes"
[ -d "$volumes_dir" ] || { echo "Error: volumes directory not found at $volumes_dir" >&2; exit 1; }

containers=$(docker ps -q)

tmp_tar=""
cleanup() {
  if [ -n "$containers" ]; then
    docker unpause $containers 2>/dev/null || true
  fi
  [ -n "$tmp_tar" ] && rm -f "$tmp_tar"
}
trap cleanup EXIT

[ -n "$containers" ] && docker pause $containers

staging="$(mktemp -d)"
ln -sf "$volumes_dir" "$staging/volumes"
ln -sf "$repo_path" "$staging/repo"

tmp_tar="$(mktemp /tmp/backup-XXXXXX.tar.gz)"
tar -czf "$tmp_tar" --dereference -C "$staging" volumes repo
rm -rf "$staging"

mv "$tmp_tar" "$dest_path"
echo "Backup written to $dest_path"
