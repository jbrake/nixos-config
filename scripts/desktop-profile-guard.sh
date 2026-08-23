#!/usr/bin/env bash

framework_desktop_for_profile() {
  local profile="$1"
  local host="$2"

  case "$profile" in
    "$host")
      printf '%s\n' plasma
      ;;
    "$host-gnome")
      printf '%s\n' gnome
      ;;
    "$host-cinnamon")
      printf '%s\n' cinnamon
      ;;
    "$host-cosmic")
      printf '%s\n' cosmic
      ;;
    "$host-hyprland")
      printf '%s\n' hyprland
      ;;
    *)
      return 1
      ;;
  esac
}

guard_framework_live_desktop() {
  local current_profile="$1"
  local requested_profile="$2"
  local target_host="$3"
  local running_host="$4"
  local switch_script="$5"

  case "$running_host" in
    framework-amd-ai-300 | framework-intel-core-ultra) ;;
    *) return 0 ;;
  esac

  if [[ "$target_host" != "$running_host" ]]; then
    echo "Refusing to activate the $target_host configuration on $running_host." >&2
    exit 1
  fi

  local current_desktop
  if ! current_desktop="$(framework_desktop_for_profile "$current_profile" "$running_host")"; then
    echo "Unsupported active Framework profile: $current_profile" >&2
    exit 1
  fi

  local requested_desktop
  if ! requested_desktop="$(framework_desktop_for_profile "$requested_profile" "$running_host")"; then
    echo "Unsupported Framework profile: $requested_profile" >&2
    exit 1
  fi

  if [[ "$current_desktop" != "$requested_desktop" ]]; then
    echo "Refusing a live desktop change from $current_desktop to $requested_desktop." >&2
    echo "Schedule it safely with: sudo $switch_script $requested_desktop" >&2
    exit 1
  fi
}
