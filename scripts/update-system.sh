#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

default_host="$(hostname 2>/dev/null || true)"
if [[ -z "$default_host" || ! -d "$repo_root/hosts/$default_host" ]]; then
  default_host="framework-amd-ai-300"
fi

host="${1:-$default_host}"
flake_ref="path:$repo_root#$host"

if [[ ! -d "$repo_root/hosts/$host" ]]; then
  echo "Unknown host: $host" >&2
  echo "Available hosts:" >&2
  find "$repo_root/hosts" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
  exit 1
fi

cd "$repo_root"

echo "Running: nix flake update"
nix flake update

echo "Running: sudo nixos-rebuild switch --flake $flake_ref"
sudo nixos-rebuild switch --flake "$flake_ref"
