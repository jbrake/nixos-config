{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.plasma = {
    enable = mkEnableOption "KDE Plasma desktop environment";
  };

  config = mkIf config.desktops.plasma.enable {
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;
    
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