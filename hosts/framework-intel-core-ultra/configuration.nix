{ lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the newest kernel packaged by the stable branch for this new Intel
  # platform while keeping the rest of the system on one coherent package set.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  services.xserver.videoDrivers = [ "modesetting" ];

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];
}
