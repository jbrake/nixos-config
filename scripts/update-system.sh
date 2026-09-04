#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
# shellcheck source=scripts/desktop-profile-guard.sh
source "$script_dir/desktop-profile-guard.sh"

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

guard_framework_live_desktop \
  "$default_profile" "$profile" "$host" "$(hostname)" \
  "$script_dir/switch-desktop.sh"

hardware_file="$repo_root/hosts/$host/hardware-configuration.nix"

if grep -q 'INTEL_HARDWARE_PLACEHOLDER' "$hardware_file"; then
  echo "Refusing to update $profile with its placeholder hardware configuration." >&2
  echo "Replace $hardware_file with nixos-generate-config output first." >&2
  exit 1
fi

cd "$repo_root"

lock_backup="$(mktemp)"
tone3000_backup="$(mktemp)"
cp --preserve=mode,timestamps flake.lock "$lock_backup"
cp --preserve=mode,timestamps packages/tone3000.nix "$tone3000_backup"
restore_updates=true

cleanup() {
  status=$?
  if [[ "$restore_updates" == true && $status -ne 0 ]]; then
    echo "Update failed — restoring the previous inputs and packages." >&2
    cp "$lock_backup" flake.lock
    cp "$tone3000_backup" packages/tone3000.nix
  fi
  rm -f "$lock_backup" "$tone3000_backup"
  trap - EXIT
  exit "$status"
}
trap cleanup EXIT

echo "Running: nix flake update"
nix flake update

echo "Checking TONE3000 for a new GitHub release..."
nix develop --command nix-update tone3000 \
  --flake \
  --url https://github.com/tone-3000/tone3000-plugin \
  --override-filename packages/tone3000.nix

# A bad update must not strand the lock file or package expression: prove the
# system builds before switching, and restore both if it does not.
echo "Verifying the updated inputs build..."
if ! nix build "path:$repo_root#nixosConfigurations.\"$profile\".config.system.build.toplevel" --no-link; then
  echo "Build failed with updated inputs." >&2
  echo "Retry the update in a few days; the fix has to land upstream." >&2
  exit 1
fi

restore_updates=false

echo "Running: sudo nixos-rebuild switch --flake $flake_ref"
sudo nixos-rebuild switch --flake "$flake_ref"
