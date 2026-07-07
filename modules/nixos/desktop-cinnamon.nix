{ pkgs, ... }:

# Cinnamon for the vm-cinnamon guest. X11 desktop — SPICE resize goes
# through the classic XRandR path here, no Wayland caveats.
{
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    brave
    ghostty
  ];
}
