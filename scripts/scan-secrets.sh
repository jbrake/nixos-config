#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

cd "$repo_root"

echo "Scanning Git history for secrets"
gitleaks git --config .gitleaks.toml --redact --no-banner .

echo "Scanning the working tree for secrets"
gitleaks dir --config .gitleaks.toml --redact --no-banner .
