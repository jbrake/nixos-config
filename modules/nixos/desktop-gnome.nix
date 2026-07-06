{ pkgs, ... }:

# GNOME desktop for the qemu-vm guest. Deliberately lean compared to
# desktop-plasma.nix: no Steam, no KDE Connect, no app pile — the VM is a
# sandbox, not a daily driver.
{
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
