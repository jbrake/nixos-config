#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  echo "Usage: $0"
  echo "Update and build TONE3000 using the current flake inputs, without activating a system."
  [[ $# == 1 && ( "$1" == --help || "$1" == -h ) ]] && exit 0
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
cd "$repo_root"

package_backup="$(mktemp)"
cleanup() {
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "TONE3000 update failed — restoring the previous package expression." >&2
    cp --preserve=mode,timestamps "$package_backup" packages/tone3000.nix
  fi
  rm -f "$package_backup"
  trap - EXIT
  exit "$status"
}
cp --preserve=mode,timestamps packages/tone3000.nix "$package_backup"
trap cleanup EXIT

echo "Checking TONE3000 for a new GitHub release..."
nix develop --no-update-lock-file --command nix-update tone3000 \
  --flake \
  --url https://github.com/tone-3000/tone3000-plugin \
  --override-filename packages/tone3000.nix

echo "Verifying TONE3000 builds with the current inputs..."
nix build "$repo_root#tone3000" --no-link --no-update-lock-file

echo "TONE3000 is ready. Review git diff, then apply with: $script_dir/rebuild.sh"
