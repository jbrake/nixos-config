#!/usr/bin/env bash

# NixOS Configuration Update Script
# Makes it easy to pull and apply updates from the git repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Detect hostname to determine which configuration to use
HOSTNAME=$(hostname)

# Map hostnames to flake configurations
case "$HOSTNAME" in
    "jason-framework")
        FLAKE_TARGET="jason-framework"
        ;;
    "lanna-nixos")
        FLAKE_TARGET="lanna-laptop"
        ;;
    "vm-test")
        FLAKE_TARGET="vm-test"
        ;;
    *)
        print_error "Unknown hostname: $HOSTNAME. Please add it to the update script."
        ;;
esac

print_status "Updating NixOS configuration for: $FLAKE_TARGET"

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
    print_error "Not in nixos-config directory. Please cd to the repository first."
fi

# Pull latest changes from git
if [ -d ".git" ]; then
    print_status "Pulling latest changes from git..."
    git pull || print_warning "Could not pull from git. Continuing with local changes."
else
    print_warning "Not a git repository. Skipping git pull."
fi

# Update flake inputs (optional, comment out if you want to keep versions pinned)
read -p "Do you want to update all flake inputs to latest versions? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Updating flake inputs..."
    nix flake update
fi

# Test the configuration first
print_status "Testing configuration..."
sudo nixos-rebuild test --flake .#$FLAKE_TARGET || print_error "Configuration test failed!"

# Ask for confirmation before switching
read -p "Configuration test successful. Apply changes permanently? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Applying configuration..."
    sudo nixos-rebuild switch --flake .#$FLAKE_TARGET
    print_status "Configuration applied successfully!"
    
    # Ask about reboot for desktop environment changes
    read -p "Reboot now? (recommended if you changed desktop environments) (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting..."
        sudo reboot
    fi
else
    print_status "Configuration not applied. Run 'sudo nixos-rebuild switch --flake .#$FLAKE_TARGET' to apply later."
fi