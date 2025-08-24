{ config, pkgs, lib, ... }:

{
  # Desktop Environment for Lanna's laptop
  # She's a KDE user, so this stays fixed
  
  desktops = {
    plasma.enable = true;       # KDE Plasma 6
    gnome.enable = false;       # GNOME
    hyprland.enable = false;    # Hyprland (Wayland compositor)
    xfce.enable = false;        # XFCE
    sway.enable = false;        # Sway (i3-like Wayland)
  };
}