{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../modules/desktop-environments/plasma.nix
  ];

  # Enable KDE Plasma desktop
  desktops.plasma.enable = true;
}