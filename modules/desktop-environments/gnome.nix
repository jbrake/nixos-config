{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.gnome = {
    enable = mkEnableOption "GNOME desktop environment";
  };

  config = mkIf config.desktops.gnome.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnome-extension-manager
      gnomeExtensions.appindicator
      gnomeExtensions.dash-to-dock
    ];

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome.epiphany
      gnome.geary
    ];
  };
}