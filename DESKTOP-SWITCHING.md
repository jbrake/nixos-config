# Desktop Environment Switching Guide

Your NixOS configuration now supports clean, isolated desktop environment switching similar to Fedora Atomic variants (Bluefin, Bazzite, Aurora).

## Available Desktop Environments

- **GNOME** (jason-framework-gnome) - Modern Wayland desktop with excellent fractional scaling
- **KDE Plasma** (jason-framework-plasma) - Full-featured, highly customizable desktop
- **XFCE** (jason-framework-xfce) - Lightweight, traditional desktop
- **Hyprland** (jason-framework-hyprland) - Advanced tiling Wayland compositor
- **Sway** (jason-framework-sway) - i3-like tiling Wayland compositor

## How to Switch Desktop Environments

### Method 1: Interactive Script (Recommended)
```bash
cd /home/jason/Documents/nixos-config
./switch-desktop.sh
```

This script will:
1. Show all available desktop options
2. Build the target configuration (no changes yet)
3. Set it for the next boot
4. Reboot to cleanly switch (avoids black screens)

### Method 2: Direct Command
```bash
# Safer flow to avoid display manager glitches:
sudo nixos-rebuild boot --flake .#jason-framework-DESKTOP && sudo reboot
```

Replace `DESKTOP` with: `gnome`, `plasma`, `xfce`, `hyprland`, or `sway`.

**Important:** Always reboot after switching. Using `switch` or `test` mid-session can restart the display manager and briefly blank the screen.

## Data Safety
- Switching desktops changes only system configuration. Your home files remain intact.
- App settings can differ per desktop. We set sane defaults (e.g., Adwaita on GNOME) to reduce cross-DE mixing.

## What Changed

### Before (Problematic)
- All desktop environments loaded simultaneously
- Multiple display managers conflicting (GDM, SDDM, LightDM)
- Mixed themes and icon sets causing visual inconsistencies
- Black cursor and scaling issues
- System instability during switches

### After (Clean Isolation)
- Each desktop environment is completely isolated
- Only one display manager per configuration
- Consistent theming within each environment
- Proper cursor and scaling configuration
- Clean reboots ensure no conflicts

## Key Improvements

### GNOME Configuration
- ✅ Fixed black cursor by forcing Adwaita cursor/icon themes via dconf
- ✅ Enabled fractional scaling with experimental features
- ✅ Removed conflicting icon themes (no more KDE icons in GNOME)
- ✅ Proper Wayland configuration for best scaling
- ✅ GDM display manager only

### General Improvements
- ✅ Desktop switching requires reboot (prevents conflicts)
- ✅ Each desktop has isolated package sets
- ✅ No more simultaneous desktop environment loading
- ✅ Clean theme isolation (no cross-desktop contamination)

## Current Desktop
To see which desktop you're currently running:
```bash
echo $XDG_CURRENT_DESKTOP
```

## Troubleshooting

### If a desktop switch fails:
1. Check the error output from the nixos-rebuild command
2. Build without switching first: `nix build .#nixosConfigurations.jason-framework-DESKTOP.config.system.build.toplevel`
3. If issues persist, check the specific desktop module in `modules/desktop-environments/`

### If you see KDE icons in GNOME or a black cursor:
1. Reboot after switching (required to avoid mixed services).
2. Reset user overrides that can leak between desktops:
   - Reset GNOME interface: `dconf reset -f /org/gnome/desktop/interface/`
   - Clear GTK caches: remove `~/.cache/gtk*` and log out/in
3. Verify Settings → Appearance shows Adwaita for icons and cursor.

## Legacy Compatibility
The old `jason-framework` configuration still works and defaults to GNOME for backward compatibility.
