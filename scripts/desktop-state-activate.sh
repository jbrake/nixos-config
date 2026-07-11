#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: desktop-state-activate.sh <plasma|gnome|cinnamon|cosmic> <home> [owner] [group]}"
home="${2:?usage: desktop-state-activate.sh <plasma|gnome|cinnamon|cosmic> <home> [owner] [group]}"
owner="${3:-jason}"
group="${4:-users}"

case "$target" in
  plasma | gnome | cinnamon | cosmic) ;;
  *)
    echo "Unsupported desktop state target: $target" >&2
    exit 1
    ;;
esac

if [[ "$home" != /* || "$home" == "/" || ! -d "$home" ]]; then
  echo "Unsafe or missing home directory: $home" >&2
  exit 1
fi

state_root="$home/.local/state/desktop-profiles"
marker="$state_root/current"
pending="$state_root/pending"

if [[ -L "$state_root" ]]; then
  echo "Refusing to use a symlink as the desktop state directory: $state_root" >&2
  exit 1
fi

install -d -m 700 -o root -g root "$state_root"

write_marker() {
  local value="$1"
  printf '%s\n' "$value" >"$state_root/.current.new"
  chmod 600 "$state_root/.current.new"
  mv -f "$state_root/.current.new" "$marker"
}

if [[ ! -f "$marker" ]]; then
  # The first activation adopts the currently running desktop without moving
  # live files. The first later switch will save that state before replacing it.
  write_marker "$target"
  echo "Initialized desktop state tracking for $target"
  exit 0
fi

current="$(<"$marker")"
case "$current" in
  plasma | gnome | cinnamon | cosmic) ;;
  *)
    echo "Invalid desktop state marker: $current" >&2
    exit 1
    ;;
esac

declare -A seen=()
managed_paths=()

add_path() {
  local relative="$1"
  if [[ -z "$relative" || "$relative" == /* || "/$relative/" == *"/../"* ]]; then
    echo "Refusing unsafe managed path: $relative" >&2
    exit 1
  fi
  if [[ -z "${seen[$relative]:-}" && ( -e "$home/$relative" || -L "$home/$relative" ) ]]; then
    seen[$relative]=1
    managed_paths+=("$relative")
  fi
}

collect_named_children() {
  local base="$1"
  shift
  [[ -d "$home/$base" ]] || return 0

  local expression=()
  local pattern
  for pattern in "$@"; do
    if [[ ${#expression[@]} -gt 0 ]]; then
      expression+=( -o )
    fi
    expression+=( -name "$pattern" )
  done

  local path
  while IFS= read -r -d '' path; do
    add_path "${path#"$home/"}"
  done < <(find "$home/$base" -mindepth 1 -maxdepth 1 \( "${expression[@]}" \) -print0)
}

collect_paths() {
  seen=()
  managed_paths=()

  local path
  for path in \
    ".gtkrc-2.0" \
    ".cinnamon" \
    ".icons" \
    ".themes" \
    ".config/dconf" \
    ".config/gtk-3.0" \
    ".config/gtk-4.0" \
    ".config/monitors.xml" \
    ".config/xsettingsd" \
    ".local/share/icons" \
    ".local/share/themes"; do
    add_path "$path"
  done

  collect_named_children ".config" \
    "KDE" \
    "baloo*" \
    "breeze*" \
    "cinnamon*" \
    "cosmic*" \
    "dolphin*" \
    "goa-1.0" \
    "gnome*" \
    "ibus" \
    "kactivitymanagerd*" \
    "kate*" \
    "kcm*" \
    "kconf*" \
    "kded*" \
    "kdedefaults" \
    "kdeconnect" \
    "kdeglobals" \
    "kglobal*" \
    "khotkey*" \
    "klipper*" \
    "konsole*" \
    "krunner*" \
    "kscreen*" \
    "kwin*" \
    "nautilus" \
    "nemo*" \
    "plasma*" \
    "powerdevil*" \
    "qt5ct" \
    "qt6ct" \
    "spectacle*" \
    "systemsettings*" \
    "Trolltech.conf" \
    "xdg-desktop-portal"

  collect_named_children ".local/share" \
    "baloo" \
    "color-schemes" \
    "cinnamon*" \
    "cosmic*" \
    "dolphin" \
    "evolution" \
    "gnome-shell" \
    "gvfs-metadata" \
    "kactivitymanagerd" \
    "kate" \
    "kded*" \
    "kdeconnect" \
    "keyrings" \
    "klipper" \
    "knewstuff*" \
    "konsole" \
    "kscreen" \
    "kwalletd" \
    "kxmlgui*" \
    "nautilus" \
    "nemo*" \
    "plasma*" \
    "sddm"

  collect_named_children ".local/state" \
    "cinnamon*" \
    "cosmic*"
}

save_current_state() {
  local desktop="$1"
  local capsule="$state_root/$desktop"
  local temporary="$state_root/.${desktop}.new"
  local previous="$state_root/.${desktop}.previous"

  rm -rf -- "$temporary" "$previous"
  install -d -m 700 -o root -g root "$temporary"

  collect_paths
  local relative parent
  for relative in "${managed_paths[@]}"; do
    parent="$(dirname -- "$relative")"
    if [[ "$parent" != "." ]]; then
      install -d -m 700 -o "$owner" -g "$group" "$temporary/$parent"
    fi
    cp -a -- "$home/$relative" "$temporary/$relative"
  done

  if [[ -e "$capsule" ]]; then
    mv -- "$capsule" "$previous"
  fi
  mv -- "$temporary" "$capsule"
  rm -rf -- "$previous"
}

clear_live_state() {
  collect_paths
  local relative
  for relative in "${managed_paths[@]}"; do
    rm -rf -- "${home:?}/$relative"
  done
}

restore_state() {
  local desktop="$1"
  local capsule="$state_root/$desktop"
  if [[ -d "$capsule" ]]; then
    cp -a -- "$capsule/." "$home/"
    echo "Restored saved $desktop desktop state"
  else
    echo "No saved $desktop state exists; starting it clean"
  fi
}

clear_desktop_caches() {
  [[ -d "$home/.cache" ]] || return 0
  find "$home/.cache" -mindepth 1 -maxdepth 1 \
    \( -name 'cinnamon*' -o -name 'cosmic*' -o -name 'gnome-shell*' \
    -o -name 'gtk-*' -o -name 'ksycoca*' -o -name 'kwin*' \
    -o -name 'nemo*' -o -name 'plasma*' \) -exec rm -rf -- {} +
}

finish_transition() {
  local destination="$1"
  clear_live_state
  restore_state "$destination"
  clear_desktop_caches
  write_marker "$destination"
  rm -f -- "$pending"
  echo "Desktop state is ready for $destination"
}

if [[ -f "$pending" ]]; then
  read -r pending_from pending_to <"$pending"
  if [[ "$current" == "$pending_to" ]]; then
    rm -f -- "$pending"
  elif [[ "$target" == "$pending_to" || "$target" == "$pending_from" ]]; then
    # Complete an interrupted transition, or restore the source capsule when
    # booting back into the source generation from the NixOS boot menu.
    finish_transition "$target"
  else
    echo "Cannot reconcile pending transition $pending_from -> $pending_to with target $target" >&2
    exit 1
  fi
  exit 0
fi

if [[ "$current" == "$target" ]]; then
  exit 0
fi

# Save atomically before marking the transition pending. If saving fails, the
# live state and current marker remain untouched. Once pending exists, a later
# boot finishes from the saved capsule instead of overwriting it with a partial
# live tree.
save_current_state "$current"
printf '%s %s\n' "$current" "$target" >"$pending"
chmod 600 "$pending"
finish_transition "$target"
