# INTEL_HARDWARE_PLACEHOLDER
#
# This file exists only so the planned host can be evaluated in CI. Replace it
# with nixos-generate-config output before installing or rebuilding that host.
{ lib, ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_PLACEHOLDER";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT_PLACEHOLDER";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
