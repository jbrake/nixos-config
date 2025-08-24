{ config, pkgs, lib, ... }:

{
  # Desktop Environment Selection for VM testing
  # Change this to test different desktop environments
  
  desktops = {
    plasma.enable = false;      # KDE Plasma 6
    gnome.enable = false;       # GNOME
    hyprland.enable = false;    # Hyprland (Wayland compositor)
    xfce.enable = true;         # XFCE (lightweight for VMs)
    sway.enable = false;        # Sway (i3-like Wayland)
  };
}