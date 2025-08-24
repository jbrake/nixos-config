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
    # Can add Lanna as a user here too for testing her setup
    # ../../modules/users/lanna.nix
  ];

  # Bootloader for VMs
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Standard kernel for VMs
  boot.kernelPackages = pkgs.linuxPackages;

  # Hostname
  networking.hostName = "vm-test";

  # VM-specific optimizations
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;
  
  # Reduce resource usage for testing
  documentation.enable = false;
  documentation.nixos.enable = false;

  # This value determines the NixOS release
  system.stateVersion = "25.05";
}