{
  lib,
  pkgs,
  username,
  modulesPath,
  ...
}:

# Shared plumbing for QEMU/KVM guests run under virt-manager on the
# laptops. Pair this with one desktop-*.nix module per VM; see the
# README's "VM Guest" section for the virt-manager side (UEFI firmware,
# virtio video, GL toggles).
{
  imports = [
    # virtio drivers in the initrd, sensible defaults for a KVM guest
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # systemd-boot needs UEFI: create the VM with firmware set to UEFI/OVMF
  # in virt-manager (Overview -> Firmware), not the BIOS default.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Desktop modules may enable laptop-oriented dependencies by default. Guests
  # have no battery or Bluetooth hardware and do not need host update services.
  hardware.bluetooth.enable = lib.mkForce false;
  services.fwupd.enable = lib.mkForce false;
  services.upower.enable = lib.mkForce false;
  services.power-profiles-daemon.enable = lib.mkForce false;

  # Sandbox VMs don't need the full name on their login screens.
  users.users.${username}.description = "Jason";

  # Lets virt-manager see the guest IP and do clean shutdowns/snapshots.
  services.qemuGuest.enable = true;
  # Clipboard sharing and display auto-resize over SPICE.
  services.spice-vdagentd.enable = true;

  # The user unit below is the single session-agent owner. Mask the package's
  # XDG autostart entry so desktops that still honor it cannot start a second
  # agent and create a restart loop.
  environment.etc."xdg/autostart/spice-vdagent.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=SPICE vdagent (managed by systemd)
    Hidden=true
  '';

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
      # The unit races the desktop's import of DISPLAY/WAYLAND_DISPLAY into
      # the user manager at login; losing the race makes vdagent exit 0
      # after ~30ms, so plain on-failure never retries. Restart
      # unconditionally — the second attempt sees the imported environment
      # and sticks.
      Restart = "always";
      RestartSec = 2;
    };
  };
}
