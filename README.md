# Multi-Host NixOS Configuration

A flexible, multi-user NixOS configuration system with easily switchable desktop environments and support for multiple machines.

## Features

- **Multi-host support** - Manage configurations for multiple machines from one repository
- **Modular design** - Separated concerns for easy maintenance
- **Multiple desktop environments** - Switch between Plasma, GNOME, Hyprland, XFCE, and Sway (one per boot)
- **Flake-based** - Reproducible builds with pinned dependencies
- **Framework laptop optimized** - Includes Framework 13 AMD hardware support
- **Bleeding-edge options** - Get the latest packages when you want them

## Repository Name Suggestions

- `nix-configs` - Simple and clear
- `nixos-family` - If family-focused
- `dotfiles-nix` - Common pattern

## Supported Hosts

- **jason-framework** - Jason's Framework 13 laptop (desktop switching enabled)
- **lanna-laptop** - Lanna's laptop (KDE Plasma fixed)
- **vm-test** - Testing environment for experiments

## Quick Start

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/nix-configs.git
   cd nix-configs
   ```

2. **Copy your hardware configuration:**
   ```bash
   # For Jason's Framework:
   sudo cp /etc/nixos/hardware-configuration.nix hosts/jason-framework/
   
   # For Lanna's laptop:
   sudo cp /etc/nixos/hardware-configuration.nix hosts/lanna-laptop/
   ```

3. **Apply the configuration:**
   ```bash
   # For Jason's Framework:
   sudo nixos-rebuild switch --flake .#jason-framework
   
   # For Lanna's laptop:
   sudo nixos-rebuild switch --flake .#lanna-laptop
   ```

### Easy Updates

Use the included update script:
```bash
./update.sh
```

This script will:
- Detect which machine you're on
- Pull latest changes from git
- Optionally update flake inputs
- Build the target configuration (no changes yet)
- Set it as the next boot target and reboot (recommended)

### Manual Updates from Remote

For Lanna or anyone else to get updates you've pushed:
```bash
cd ~/nix-configs  # or wherever the repo is cloned
git pull
# Safer: set next boot then reboot, avoids DM restarts
sudo nixos-rebuild boot --flake .#lanna-laptop && sudo reboot
```

## Switching Desktop Environments (Jason's machine only)

**NEW: Clean Desktop Switching!** 🎉

The configuration now supports seamless desktop switching like Fedora Atomic variants (Bluefin/Bazzite).

### Easy Method (Recommended)
```bash
./switch-desktop.sh
```

This interactive script will:
- Show available desktop options
- Build the target configuration
- Set it for next boot and reboot cleanly

### Manual Method
```bash
# Set next boot target, then reboot (recommended)
sudo nixos-rebuild boot --flake .#jason-framework-gnome && sudo reboot
sudo nixos-rebuild boot --flake .#jason-framework-plasma && sudo reboot
sudo nixos-rebuild boot --flake .#jason-framework-xfce && sudo reboot
sudo nixos-rebuild boot --flake .#jason-framework-hyprland && sudo reboot
sudo nixos-rebuild boot --flake .#jason-framework-sway && sudo reboot
```

**Why the reboot?** Each desktop environment has its own display manager and services. Rebooting avoids mid-session DM restarts (black screens) and keeps environments isolated.

See `DESKTOP-SWITCHING.md` for detailed information.

## Getting Fresher Packages

### Option 1: Standard Unstable
The default `flake.nix` uses nixos-unstable, which is reasonably fresh.

### Option 2: Bleeding Edge
Use `flake-bleeding-edge.nix` for the absolute latest:
```bash
sudo nixos-rebuild switch --flake ./flake-bleeding-edge.nix#jason-framework
```

### Option 3: Chaotic-Nyx (Recommended for latest KDE)
Use `flake-chaotic.nix` for pre-built bleeding-edge packages:
```bash
sudo nixos-rebuild switch --flake ./flake-chaotic.nix#jason-framework
```

This gives you:
- Latest KDE Plasma packages
- Latest Mesa drivers
- Pre-built binaries (faster than building from source)

## Testing Lanna's Configuration on Jason's Machine

You can test Lanna's setup in a VM:
```bash
# Build a VM with her configuration
nixos-rebuild build-vm --flake .#lanna-laptop

# Run the VM
./result/bin/run-lanna-laptop-vm
```

Or temporarily switch to her configuration (backup your home directory first!):
```bash
sudo nixos-rebuild test --flake .#lanna-laptop
# This won't persist after reboot
```

## Project Structure

```
nix-configs/
├── flake.nix                          # Main flake configuration
├── flake-bleeding-edge.nix            # Alternative with fresher packages
├── flake-chaotic.nix                  # Alternative with Chaotic-Nyx
├── update.sh                          # Update helper script
├── hosts/
│   ├── jason-framework/               # Jason's Framework laptop
│   │   ├── configuration.nix
│   │   ├── desktops/                  # Per-DE entry points
│   │   │   ├── gnome.nix
│   │   │   ├── plasma.nix
│   │   │   ├── xfce.nix
│   │   │   ├── hyprland.nix
│   │   │   └── sway.nix
│   │   └── hardware-configuration.nix
│   ├── lanna-laptop/                  # Lanna's laptop
│   │   ├── configuration.nix
│   │   ├── desktop.nix                # Fixed to KDE
│   │   └── hardware-configuration.nix
│   └── vm-test/                       # Testing VM
│       ├── configuration.nix
│       ├── desktop.nix
│       └── hardware-configuration.nix
└── modules/
    ├── desktop-environments/           # Desktop modules
    │   ├── gnome.nix
    │   ├── hyprland.nix
    │   ├── plasma.nix
    │   ├── sway.nix
    │   └── xfce.nix
    ├── system/
    │   ├── core.nix                   # Core system settings
    │   └── bleeding-edge.nix          # Optional fresh packages
    └── users/
        ├── jason.nix                  # Jason's packages
        └── lanna.nix                  # Lanna's packages
```

## Working with Multiple Machines

### Adding a New Machine

1. Create a new host directory:
   ```bash
   mkdir hosts/new-machine
   ```

2. Copy configuration files from a similar machine:
   ```bash
   cp -r hosts/vm-test/* hosts/new-machine/
   ```

3. Add it to `flake.nix`:
   ```nix
   new-machine = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     specialArgs = { inherit inputs; };
     modules = [
       ./hosts/new-machine/configuration.nix
     ];
   };
   ```

4. Update the `update.sh` script to recognize the new hostname

### Sharing Common Configurations

Put shared settings in modules:
- `modules/system/core.nix` - System-wide settings
- `modules/users/` - User-specific packages
- `modules/desktop-environments/` - Desktop configurations

## Tips for Lanna

Since Lanna has less Linux experience, here are simple commands:

### Daily Use
- **Update system**: Just run `./update.sh` and follow prompts
- **See what changed**: `git log --oneline`
- **Check for updates**: `git fetch && git status`

### If Something Breaks
- **Revert to previous version**: `sudo nixos-rebuild switch --rollback`
- **List previous versions**: `sudo nix-env --list-generations -p /nix/var/nix/profiles/system`
- **Switch to specific version**: `sudo nix-env --switch-generation 42 -p /nix/var/nix/profiles/system`

## Troubleshooting

### Can't Pull Updates
```bash
git stash        # Save local changes
git pull         # Get updates
git stash pop    # Restore local changes
```

### `nix flake update` fails due to lockfile permissions
If `flake.lock` is owned by root, `nix flake update` as your user will fail. Fix with:
```bash
sudo chown $USER:$(id -gn) flake.lock
```

### Wrong Hostname Detection
Edit `update.sh` and add your hostname to the case statement.

### Fresh Install on New Machine
```bash
# On new NixOS install:
git clone https://github.com/YOUR_USERNAME/nix-configs.git
cd nix-configs
sudo nixos-generate-config --show-hardware-config > hosts/YOUR_HOST/hardware-configuration.nix
# Edit hosts/YOUR_HOST/configuration.nix with your hostname
sudo nixos-rebuild switch --flake .#YOUR_HOST
```

## License

Feel free to use and modify this configuration for your own needs.
