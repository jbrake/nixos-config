#!/usr/bin/env bash

# NixOS Desktop Environment Switcher
# Provides clean desktop switching similar to Fedora Atomic variants

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_info() {
    echo -e "${BLUE}Info:${NC} $1"
}

# Detect hostname to determine which configuration to use
HOSTNAME=$(hostname)

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
    print_error "Not in nixos-config directory. Please cd to the repository first."
fi

# Display available desktop environments
print_info "Available desktop environments for $HOSTNAME:"
echo
echo "1. GNOME (Wayland, great fractional scaling, modern)"
echo "2. KDE Plasma (Full-featured, customizable)"
echo "3. XFCE (Lightweight, traditional)"
echo "4. Hyprland (Tiling Wayland compositor, advanced)"
echo "5. Sway (i3-like Wayland compositor)"
echo

# Get user choice
while true; do
    read -p "Select desktop environment (1-5): " choice
    case $choice in
        1)
            DESKTOP="gnome"
            DESKTOP_NAME="GNOME"
            break
            ;;
        2)
            DESKTOP="plasma"
            DESKTOP_NAME="KDE Plasma"
            break
            ;;
        3)
            DESKTOP="xfce"
            DESKTOP_NAME="XFCE"
            break
            ;;
        4)
            DESKTOP="hyprland"
            DESKTOP_NAME="Hyprland"
            break
            ;;
        5)
            DESKTOP="sway"
            DESKTOP_NAME="Sway"
            break
            ;;
        *)
            print_warning "Invalid choice. Please select 1-5."
            ;;
    esac
done

# Map hostnames to flake configurations
case "$HOSTNAME" in
    "jason-framework")
        FLAKE_TARGET="jason-framework-$DESKTOP"
        ;;
    "lanna-nixos")
        FLAKE_TARGET="lanna-laptop-$DESKTOP"
        ;;
    "vm-test")
        FLAKE_TARGET="vm-test-$DESKTOP"
        ;;
    *)
        print_error "Unknown hostname: $HOSTNAME. Please add it to the script."
        ;;
esac

print_status "Switching to $DESKTOP_NAME desktop environment..."
print_info "Configuration: $FLAKE_TARGET"

# Test the configuration first
print_status "Building configuration (no changes applied yet)..."
if ! nix build ".#nixosConfigurations.${FLAKE_TARGET}.config.system.build.toplevel"; then
    print_error "Build failed! Check the error output above."
fi
print_status "Build successful."

# Ask for confirmation before switching
echo
read -p "Set $DESKTOP_NAME to boot next and reboot now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    print_status "Setting $DESKTOP_NAME as next boot target..."
    sudo nixos-rebuild boot --flake ".#$FLAKE_TARGET"
    print_status "$DESKTOP_NAME configured for next boot."
    print_status "Rebooting to $DESKTOP_NAME..."
    sudo reboot
else
    print_status "Not applied. To apply later, run:"
    echo "  sudo nixos-rebuild boot --flake .#$FLAKE_TARGET && sudo reboot"
fi
