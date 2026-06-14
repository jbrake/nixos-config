#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
target_user="jason"

usage() {
  cat >&2 <<EOF
Usage: sudo $0 <host> [target-root]

Hosts:
EOF
  find "$repo_root/hosts" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

host="$1"
target_root="${2:-/mnt}"
hardware_file="$repo_root/hosts/$host/hardware-configuration.nix"
target_repo="$target_root/home/$target_user/Projects/nixos-config"

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

if ! command -v nix >/dev/null 2>&1; then
  echo "nix is not available. Run this from a NixOS installer ISO." >&2
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

echo "Locking flake inputs"
nix --extra-experimental-features "nix-command flakes" flake lock --flake "$repo_root"

if command -v git >/dev/null 2>&1 && git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$repo_root" add flake.lock
fi

echo "Installing NixOS flake: $repo_root#$host"
nixos-install --root "$target_root" --flake "$repo_root#$host" --no-root-passwd

echo "Copying generated repo to $target_repo"
mkdir -p "$(dirname -- "$target_repo")"

if [[ -d "$target_repo" && "$(readlink -f "$target_repo")" == "$(readlink -f "$repo_root")" ]]; then
  echo "Repo is already at $target_repo"
else
  mkdir -p "$target_repo"
  cp -a "$repo_root/." "$target_repo/"
fi

chown 1000:100 "$target_root/home/$target_user" "$target_root/home/$target_user/Projects"
chown -R 1000:100 "$target_repo"

echo "Install finished. Reboot, log in as $target_user with password 'changeme', then run passwd."
echo "Your generated config repo will be at /home/$target_user/Projects/nixos-config."
