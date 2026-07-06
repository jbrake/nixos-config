{ pkgs, ... }:

# GNOME desktop for the qemu-vm guest. Deliberately lean compared to
# desktop-plasma.nix: no Steam, no KDE Connect, no app pile — the VM is a
# sandbox, not a daily driver.
{
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # 150% scaling. Text scaling is used instead of display scaling because
  # SPICE resizes the virtual display with the virt-manager window, and
  # GNOME stores display scale per (connector, mode) — it would silently
  # reset to 100% on every new window size. Text scaling survives resizes.
  # These are defaults, not locks; Settings can still override them.
  # scale-monitor-framebuffer additionally unlocks fractional choices in
  # Settings -> Displays if real display scaling is ever wanted.
  services.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.mutter ];
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.interface]
    text-scaling-factor=1.5

    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']
  '';

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;

  # Skip the first-run tour and GNOME's browser; brave matches the
  # BROWSER/mime defaults in home.nix, ghostty the TERMINAL default.
  environment.gnome.excludePackages = with pkgs; [
    epiphany
    gnome-tour
  ];

  environment.systemPackages = with pkgs; [
    brave
    ghostty
    gnome-tweaks
  ];
}
