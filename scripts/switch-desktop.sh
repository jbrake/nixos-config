#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
target_user="jason"
target_home="/home/$target_user"
state_root="$target_home/.local/state/desktop-profiles"
backup=false
reboot=false

usage() {
  cat <<EOF
Usage: sudo $0 <plasma|gnome|cinnamon|cosmic|hyprland> [--backup] [--reboot]

  --backup  Wait for a Restic home backup before scheduling the switch.
  --reboot  Reboot immediately after the target system builds.

Without --reboot, close applications and reboot normally when ready.
EOF
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ $# -ge 1 ]] && exit 0
  exit 1
fi

target="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)
      backup=true
      ;;
    --reboot)
      reboot=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

case "$target" in
  plasma | gnome | cinnamon | cosmic | hyprland) ;;
  *)
    echo "Desktop must be 'plasma', 'gnome', 'cinnamon', 'cosmic', or 'hyprland'." >&2
    exit 1
    ;;
esac

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

host="$(hostname)"
case "$host" in
  framework-amd-ai-300 | framework-intel-core-ultra) ;;
  *)
    echo "Desktop switching is configured only for the Framework laptop profiles." >&2
    exit 1
    ;;
esac

if [[ "$target" == "plasma" ]]; then
  target_profile="$host"
else
  target_profile="$host-$target"
fi

if [[ ! -r /etc/nixos-config-profile ]]; then
  echo "Missing /etc/nixos-config-profile. Apply the current configuration first." >&2
  exit 1
fi

current_profile="$(</etc/nixos-config-profile)"
case "$current_profile" in
  "$host")
    current="plasma"
    ;;
  "$host-gnome")
    current="gnome"
    ;;
  "$host-cinnamon")
    current="cinnamon"
    ;;
  "$host-cosmic")
    current="cosmic"
    ;;
  "$host-hyprland")
    current="hyprland"
    ;;
  *)
    echo "Unsupported active profile: $current_profile" >&2
    exit 1
    ;;
esac

if [[ "$current" == "$target" ]]; then
  echo "$target is already the active desktop."
  exit 0
fi

if [[ -L "$state_root" ]]; then
  echo "Refusing to use a symlink as the desktop state directory: $state_root" >&2
  exit 1
fi

install -d -m 700 -o root -g root "$state_root"
marker="$state_root/current"
if [[ ! -f "$marker" ]]; then
  printf '%s\n' "$current" >"$marker"
  chmod 600 "$marker"
elif [[ "$(<"$marker")" != "$current" ]]; then
  echo "Desktop state marker does not match the running profile." >&2
  echo "Reboot once before scheduling another desktop switch." >&2
  exit 1
fi

if [[ "$backup" == true ]]; then
  echo "Running a Restic backup before the desktop switch..."
  systemctl start restic-backups-jason-home.service
fi

echo "Building $target_profile for the next boot..."
nixos-rebuild boot --flake "path:$repo_root#$target_profile"

echo
echo "$target is ready for the next boot."
echo "At boot, the current $current state will be saved and the last $target state restored."
echo "Personal files and shared application profiles are not moved."

if [[ "$reboot" == true ]]; then
  echo "Rebooting now..."
  systemctl reboot
else
  echo "Close applications and reboot normally when ready."
fi
