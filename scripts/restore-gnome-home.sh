#!/usr/bin/env bash
set -euo pipefail

apply=false
if [[ "${1:-}" == "--apply" ]]; then
  apply=true
  shift
fi

source_home="${1:-/mnt/restic-restore/home/jason}"
target_home="${2:-/home/jason}"

if [[ "$apply" == true && "$(id -u)" -ne 0 ]]; then
  echo "Run the applied restore with sudo so ownership and metadata are preserved." >&2
  exit 1
fi

if [[ ! -d "$source_home" ]]; then
  echo "Restore source does not exist: $source_home" >&2
  exit 1
fi

if [[ ! -d "$target_home" ]]; then
  echo "Target home does not exist: $target_home" >&2
  exit 1
fi

# Restore personal files and deliberately selected application profiles. Do
# not copy all of .config or .local/share: those trees contain Plasma, GTK,
# cursor, portal, dconf, and keyring state that can contaminate a fresh GNOME
# profile. Add an application path here only after checking its contents.
restore_paths=(
  "Desktop"
  "Documents"
  "Downloads"
  "Music"
  "Pictures"
  "Public"
  "Templates"
  "Videos"
  ".claude"
  ".codex"
  ".gnupg"
  ".mozilla"
  ".pki"
  ".ssh"
  ".steam"
  ".config/BraveSoftware"
  ".config/discord"
  ".config/git/ignore"
  ".config/mozilla"
  ".local/share/PrismLauncher"
  ".local/share/Steam"
  ".local/share/TelegramDesktop"
  ".local/share/claude"
  ".local/share/fish"
)

sources=()
for path in "${restore_paths[@]}"; do
  if [[ -e "$source_home/$path" || -L "$source_home/$path" ]]; then
    # /./ marks the point from which rsync should preserve relative paths.
    sources+=("$source_home/./$path")
  else
    echo "Skipping absent path: $path"
  fi
done

if [[ ${#sources[@]} -eq 0 ]]; then
  echo "No selected paths exist in $source_home" >&2
  exit 1
fi

rsync_options=(
  --archive
  --hard-links
  --acls
  --xattrs
  --numeric-ids
  --relative
  --itemize-changes
  --exclude=/Documents/repos/nixos-config/
)

if [[ "$apply" == false ]]; then
  rsync_options+=(--dry-run)
  echo "Dry run only; no files will be changed."
  echo "Review the list, then repeat with --apply as the first argument."
else
  echo "Restoring selected data into $target_home"
fi

rsync "${rsync_options[@]}" "${sources[@]}" "$target_home/"
