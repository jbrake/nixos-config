#!/usr/bin/env bash
set -euo pipefail

host="${1:-framework-amd-ai-300}"
target_root="${2:-/mnt}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
hardware_file="$repo_root/hosts/$host/hardware-configuration.nix"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this from the NixOS installer as root." >&2
  exit 1
fi

if [[ ! -d "$repo_root/hosts/$host" ]]; then
  echo "Unknown host: $host" >&2
  echo "Available hosts:" >&2
  find "$repo_root/hosts" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
  exit 1
fi

if ! command -v nixos-generate-config >/dev/null 2>&1; then
  echo "nixos-generate-config is not available. Run this from a NixOS installer ISO." >&2
  exit 1
fi

if ! command -v nixos-install >/dev/null 2>&1; then
  echo "nixos-install is not available. Run this from a NixOS installer ISO." >&2
  exit 1
fi

if ! findmnt --target "$target_root" >/dev/null 2>&1; then
  echo "$target_root is not a mount point. Mount your target root filesystem first." >&2
  exit 1
fi

if [[ -f "$hardware_file" ]]; then
  cp -a "$hardware_file" "$hardware_file.bak"
fi

echo "Generating hardware configuration for $host from $target_root"
nixos-generate-config --root "$target_root" --show-hardware-config > "$hardware_file"

if command -v git >/dev/null 2>&1 && git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$repo_root" add "$hardware_file"
fi

echo "Installing NixOS flake: $repo_root#$host"
nixos-install --root "$target_root" --flake "$repo_root#$host"

echo "Install finished. Reboot, log in as jason with password 'changeme', then run passwd."
