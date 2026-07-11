#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

cd "$repo_root"

echo "Checking Nix formatting"
nix fmt -- --ci

echo "Running ShellCheck"
shellcheck scripts/*.sh

echo "Running Statix"
statix check .

echo "Running Deadnix"
# Generated hardware modules intentionally retain the standard generator
# argument shape, so unused lambda arguments are not treated as failures.
deadnix --fail --no-lambda-arg --no-lambda-pattern-names .

echo "Checking documentation links"
lychee --offline README.md docs/*.md

echo "Scanning Git history for secrets"
gitleaks git --redact --no-banner .
gitleaks dir --redact --no-banner .
