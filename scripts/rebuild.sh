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
hardware_file="$repo_root/hosts/$host/hardware-configuration.nix"

if [[ ! -d "$repo_root/hosts/$host" ]]; then
  echo "Unknown host: $host" >&2
  echo "Available hosts:" >&2
  find "$repo_root/hosts" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
  exit 1
fi

if grep -q 'INTEL_HARDWARE_PLACEHOLDER' "$hardware_file"; then
  echo "Refusing to rebuild $host with its placeholder hardware configuration." >&2
  echo "Replace $hardware_file with nixos-generate-config output first." >&2
  exit 1
fi

prev="$(readlink -f /run/current-system)"

echo "Running: sudo nixos-rebuild switch --flake $flake_ref"
sudo nixos-rebuild switch --flake "$flake_ref"

# The closure diff is NixOS's upgrade log: show what actually changed.
new="$(readlink -f /run/current-system)"
if [[ "$prev" == "$new" ]]; then
  echo "No changes: same system as before."
else
  echo
  echo "=== Package changes (this vs. previous generation) ==="
  nix store diff-closures "$prev" "$new"
fi
