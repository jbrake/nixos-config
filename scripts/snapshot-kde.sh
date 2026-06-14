#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
config_dst="$repo_root/home/jason/kde/config"
data_dst="$repo_root/home/jason/kde/data"

config_files=(
  kcminputrc
  kdeglobals
  kwinoutputconfig.json
  kwinrc
  mimeapps.list
  plasma-org.kde.plasma.desktop-appletsrc
  plasmashellrc
)

mkdir -p "$config_dst" "$data_dst/plasma/plasmoids"

for item in "${config_files[@]}"; do
  src="$HOME/.config/$item"
  dst="$config_dst/$item"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname -- "$dst")"
    cp -a "$src" "$dst"
  fi
done

thermal_src="$HOME/.local/share/plasma/plasmoids/org.kde.olib.thermalmonitor"
if [[ -d "$thermal_src" ]]; then
  rsync -a "$thermal_src/" "$data_dst/plasma/plasmoids/org.kde.olib.thermalmonitor/"
fi

echo "Updated KDE snapshot under home/jason/kde."
echo "Commit the changes, then remove ~/.local/state/nixos-config/kde-snapshot-applied or run scripts/apply-kde-snapshot.sh to reapply."
