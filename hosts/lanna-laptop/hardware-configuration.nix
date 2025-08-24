# Placeholder hardware configuration for Lanna's laptop
# Replace this with actual hardware configuration from her machine
# Run on her machine: sudo nixos-generate-config --show-hardware-config

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  # This will need to be replaced with her actual hardware configuration
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Filesystem configuration should go here
  # fileSystems."/" = { ... };
  # fileSystems."/boot" = { ... };
  # swapDevices = [ ... ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}