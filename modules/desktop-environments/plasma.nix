{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.plasma = {
    enable = mkEnableOption "KDE Plasma desktop environment";
  };

  config = mkIf config.desktops.plasma.enable {
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # Prefer KDE portal for correct file pickers/screen sharing, avoid mixed toolkits
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde pkgs.xdg-desktop-portal-gtk ];
    };
    
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    environment.systemPackages = with pkgs; [
      kdePackages.kate
      kdePackages.kdenlive
      kdePackages.kdeconnect-kde
      kdePackages.kcalc
      kdePackages.ark
      kdePackages.spectacle
    ];

    # Ensure Qt uses KDE theming when running Plasma
    qt = {
      enable = true;
      platformTheme = "kde";
      style = "breeze";
    };

    # Cursor defaults to prevent black square artifacts across DE switches
    environment.variables = {
      XCURSOR_THEME = "Breeze";
      XCURSOR_SIZE = "24";
    };

    networking.firewall = {
      allowedTCPPortRanges = [
        { from = 1714; to = 1764; } # KDE Connect
      ];
      allowedUDPPortRanges = [
        { from = 1714; to = 1764; } # KDE Connect
      ];
    };
  };
}
