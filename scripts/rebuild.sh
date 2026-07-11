#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

if [[ -r /etc/nixos-config-profile ]]; then
  read -r default_profile </etc/nixos-config-profile
else
  default_profile="$(hostname 2>/dev/null || true)"
fi
if [[ -z "$default_profile" ]]; then
  default_profile="framework-amd-ai-300"
fi

profile="${1:-$default_profile}"
flake_ref="path:$repo_root#$profile"

if ! host="$(nix eval --raw "path:$repo_root#nixosConfigurations.\"$profile\".config.networking.hostName" 2>/dev/null)"; then
  echo "Unknown NixOS profile: $profile" >&2
  echo "Run 'nix flake show' to list available profiles." >&2
  exit 1
fi

hardware_file="$repo_root/hosts/$host/hardware-configuration.nix"

if grep -q 'INTEL_HARDWARE_PLACEHOLDER' "$hardware_file"; then
  echo "Refusing to rebuild $profile with its placeholder hardware configuration." >&2
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
