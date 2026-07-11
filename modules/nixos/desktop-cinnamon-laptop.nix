_:

# Full Cinnamon desktop for physical laptops. Cinnamon's NixOS module provides
# LightDM, Nemo, portals, keyring integration, and the standard Cinnamon apps.
{
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon = {
    enable = true;

    # Match the existing Plasma touchpad behavior using Cinnamon's native,
    # user-overridable GSettings defaults.
    extraGSettingsOverrides = ''
      [org.cinnamon.desktop.peripherals.touchpad]
      tap-to-click=false
      tap-and-drag=false
      natural-scroll=true
      disable-while-typing=false
      click-method='fingers'
      two-finger-scrolling-enabled=true
      edge-scrolling-enabled=false
    '';
  };

  xdg.portal.xdgOpenUsePortal = true;

  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "com.mitchellh.ghostty.desktop" ];
      Cinnamon = [ "com.mitchellh.ghostty.desktop" ];
    };
  };
}
