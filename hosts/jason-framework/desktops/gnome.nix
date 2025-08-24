{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../modules/desktop-environments/gnome.nix
  ];

  # Enable GNOME desktop
  desktops.gnome.enable = true;
}