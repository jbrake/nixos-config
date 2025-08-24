{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../modules/desktop-environments/xfce.nix
  ];

  # Enable XFCE desktop
  desktops.xfce.enable = true;
}