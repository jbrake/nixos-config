{ modulesPath, ... }:

{
  imports = [
    # virtio drivers in the initrd, sensible defaults for a KVM guest
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
  ];

  # systemd-boot needs UEFI: create the VM with firmware set to UEFI/OVMF
  # in virt-manager (Overview -> Firmware), not the BIOS default.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Lets virt-manager see the guest IP and do clean shutdowns/snapshots.
  services.qemuGuest.enable = true;
  # Clipboard sharing and display auto-resize over SPICE.
  services.spice-vdagentd.enable = true;
}
