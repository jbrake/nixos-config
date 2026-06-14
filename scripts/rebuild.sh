#!/usr/bin/env bash
set -euo pipefail

host="${1:-framework-amd-ai-300}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

if [[ ! -d "$repo_root/hosts/$host" ]]; then
  echo "Unknown host: $host" >&2
  echo "Available hosts:" >&2
  find "$repo_root/hosts" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
  exit 1
fi

echo "Running: sudo nixos-rebuild switch --flake $repo_root#$host"
sudo nixos-rebuild switch --flake "$repo_root#$host"
