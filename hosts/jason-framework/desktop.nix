{ config, pkgs, lib, ... }:

{
  # Desktop Environment Selection
  # Set only ONE of these to true at a time
  
  desktops = {
    plasma.enable = false;     # KDE Plasma 6
    gnome.enable = true;       # GNOME
    hyprland.enable = false;    # Hyprland (Wayland compositor)
    xfce.enable = false;        # XFCE
    sway.enable = false;        # Sway (i3-like Wayland)
  };
}