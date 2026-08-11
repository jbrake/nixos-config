{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  currentPkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  imports = [ ./hardware-configuration.nix ];

  # Keep the known-smooth userspace intact, while sourcing the two pieces most
  # important to brand-new Intel hardware from current unstable.
  nixpkgs.overlays = [
    (_final: _previous: {
      inherit (currentPkgs) linux-firmware;
    })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = lib.mkDefault currentPkgs.linuxPackages_latest;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  services.xserver.videoDrivers = [ "modesetting" ];

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];
}
