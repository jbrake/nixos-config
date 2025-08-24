{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./desktop.nix
    ../../modules/desktop-environments/plasma.nix
    ../../modules/desktop-environments/gnome.nix
    ../../modules/desktop-environments/hyprland.nix
    ../../modules/desktop-environments/xfce.nix
    ../../modules/desktop-environments/sway.nix
    ../../modules/system/core.nix
    ../../modules/users/jason.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hostname - unique for each machine
  networking.hostName = "jason-framework";

  # This value determines the NixOS release
  system.stateVersion = "25.05";
}