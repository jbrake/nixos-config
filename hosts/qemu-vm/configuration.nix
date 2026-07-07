{ pkgs, username, modulesPath, ... }:

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

  # The session half of the agent normally starts via its XDG autostart
  # file, but GNOME dropped support for entries that set
  # X-GNOME-Autostart-Phase (spice-vdagent's still does), so it never
  # launches and resize/clipboard silently don't work. Run it as a user
  # unit instead.
  systemd.user.services.spice-vdagent = {
    description = "SPICE guest session agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session-pre.target" ];
    # User units start for every graphical session, including the GDM
    # greeter's. vdagentd only accepts one agent, from the active session,
    # and the greeter's copy racing the real one broke both (UID mismatch
    # rejections in the vdagentd journal).
    unitConfig.ConditionUser = username;
    serviceConfig = {
      ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
