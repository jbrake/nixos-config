#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

cd "$repo_root"

echo "Checking Nix formatting"
nix fmt -- --ci

echo "Running ShellCheck"
shellcheck scripts/*.sh tests/*.sh

echo "Testing desktop restoration and installer preflight"
fakeroot -- bash tests/scripts.sh
fakeroot -- bash tests/desktop-recovery.sh

echo "Testing independent update transactions"
bash tests/updates.sh

echo "Running Statix"
statix check .

echo "Running Deadnix"
# Generated hardware modules intentionally retain the standard generator
# argument shape, so unused lambda arguments are not treated as failures.
deadnix --fail --no-lambda-arg --no-lambda-pattern-names .

echo "Checking documentation links"
lychee --offline README.md docs/*.md

"$script_dir/scan-secrets.sh"
