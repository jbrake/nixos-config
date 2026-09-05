{ lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Existing recovery policy; retest after firmware/kernel updates using
  # docs/fingerprint.md. New hosts do not inherit controller resets by default.
  jbrake.frameworkFingerprint = {
    resetMode = "when-missing";
    keepAwake = true;
    stopBeforeSleep = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the newest kernel packaged by the stable branch for this new Intel
  # platform while keeping the rest of the system on one coherent package set.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Work around repeated beacon loss on the Intel BE211/iwlmld link. Retest
  # after future kernel and wireless-firmware updates land.
  networking.networkmanager.wifi.powersave = false;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  services.xserver.videoDrivers = [ "modesetting" ];

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];
}
