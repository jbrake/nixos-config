{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../modules/desktop-environments/hyprland.nix
  ];

  # Enable Hyprland desktop
  desktops.hyprland.enable = true;
}