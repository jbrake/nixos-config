{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.xfce = {
    enable = mkEnableOption "XFCE desktop environment";
  };

  config = mkIf config.desktops.xfce.enable {
    services.xserver.enable = true;
    services.xserver.desktopManager.xfce.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    environment.systemPackages = with pkgs; [
      xfce.xfce4-whiskermenu-plugin
      xfce.xfce4-pulseaudio-plugin
      xfce.xfce4-clipman-plugin
      xfce.xfce4-screenshooter
      xfce.thunar-volman
      xfce.thunar-archive-plugin
    ];

    # Use GTK portal for consistent dialogs/screen share
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };
  };
}
