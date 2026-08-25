#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

cd "$repo_root"

echo "Scanning Git history for secrets"
gitleaks git --config .gitleaks.toml --redact --no-banner .

scan_root="$(mktemp -d)"
trap 'rm -rf -- "$scan_root"' EXIT

while IFS= read -r -d '' path; do
  # Tracked files may be deleted in the working tree; there is nothing to copy
  # in that case. Preserve symlinks so the scan cannot escape the repository.
  if [[ -f "$path" || -L "$path" ]]; then
    cp --parents --no-dereference -- "$path" "$scan_root"
  fi
done < <(git ls-files --cached --others --exclude-standard -z)

echo "Scanning tracked and unignored working-tree files for secrets"
gitleaks dir --config .gitleaks.toml --redact --no-banner "$scan_root"
