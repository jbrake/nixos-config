#!/usr/bin/env bash
set -euo pipefail

host="${1:-framework-amd-ai-300}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

cd "$repo_root"

echo "Running: nix flake update"
nix flake update

echo "Running: sudo nixos-rebuild switch --flake $repo_root#$host"
sudo nixos-rebuild switch --flake "$repo_root#$host"
