#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
target_user="jason"

usage() {
  cat >&2 <<EOF
Usage: sudo $0 <profile> [target-root]

Examples:
  sudo $0 framework-intel-core-ultra
  sudo $0 framework-intel-core-ultra-cosmic

Hardware directories:
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

profile="$1"
target_root="${2:-/mnt}"
target_repo="$target_root/home/$target_user/Documents/repos/nixos-config"
flake_ref="path:$repo_root#$profile"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this from the NixOS installer as root." >&2
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

if ! command -v nixos-enter >/dev/null 2>&1; then
  echo "nixos-enter is not available. Run this from a NixOS installer ISO." >&2
  exit 1
fi

if ! host="$(nix --extra-experimental-features "nix-command flakes" eval --raw "path:$repo_root#nixosConfigurations.\"$profile\".config.networking.hostName" 2>/dev/null)"; then
  echo "Unknown NixOS profile: $profile" >&2
  echo "Run 'nix flake show' to list available profiles." >&2
  exit 1
fi

hardware_file="$repo_root/hosts/$host/hardware-configuration.nix"

if ! findmnt --target "$target_root" >/dev/null 2>&1; then
  echo "$target_root is not a mount point. Mount your target root filesystem first." >&2
  exit 1
fi

echo "Generating hardware configuration for $host from $target_root"
nixos-generate-config --root "$target_root" --show-hardware-config > "$hardware_file"

echo "Locking flake inputs"
nix --extra-experimental-features "nix-command flakes" flake lock --flake "path:$repo_root"

echo "Installing NixOS flake: $flake_ref"
nixos-install --root "$target_root" --flake "$flake_ref" --no-root-passwd

echo "Set the login password for $target_user"
nixos-enter --root "$target_root" -c "passwd $target_user"

echo "Copying generated repo to $target_repo"
install -d -m 755 -o 1000 -g 100 "$(dirname -- "$target_repo")"

if [[ -e "$target_repo" ]]; then
  echo "Refusing to overwrite existing target: $target_repo" >&2
  exit 1
fi

git clone --no-hardlinks "$repo_root" "$target_repo"
install -m 644 "$hardware_file" "$target_repo/hosts/$host/hardware-configuration.nix"
install -m 644 "$repo_root/flake.lock" "$target_repo/flake.lock"

if origin_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)"; then
  git -C "$target_repo" remote set-url origin "$origin_url"
fi

chown 1000:100 "$target_root/home/$target_user" "$target_root/home/$target_user/Documents" "$target_root/home/$target_user/Documents/repos"
chown -R 1000:100 "$target_repo"

echo "Install finished. Your generated config repo will be at:"
echo "/home/$target_user/Documents/repos/nixos-config"
