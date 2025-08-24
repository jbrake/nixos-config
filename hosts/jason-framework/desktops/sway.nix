{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../modules/desktop-environments/sway.nix
  ];

  # Enable Sway desktop
  desktops.sway.enable = true;
}