{ lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  services.xserver.videoDrivers = [ "modesetting" ];

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];
}
