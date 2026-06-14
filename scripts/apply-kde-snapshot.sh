#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
config_src="$repo_root/home/jason/kde/config"
data_src="$repo_root/home/jason/kde/data"
marker="$HOME/.local/state/nixos-config/kde-snapshot-applied"

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required to apply the KDE snapshot." >&2
  exit 1
fi

mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state/nixos-config"
rsync -a --chmod=Du+rwx,Dgo-rwx,Fu+rw,Fgo-rwx "$config_src/" "$HOME/.config/"
rsync -a --chmod=Du+rwx,Dgo-rwx,Fu+rw,Fgo-rwx "$data_src/" "$HOME/.local/share/"
touch "$marker"

echo "Applied KDE snapshot to $HOME."
echo "Log out and back in, or restart Plasma, for every setting to take effect."
