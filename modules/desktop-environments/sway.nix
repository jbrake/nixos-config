{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.sway = {
    enable = mkEnableOption "Sway window manager";
  };

  config = mkIf config.desktops.sway.enable {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    environment.systemPackages = with pkgs; [
      swaylock
      swayidle
      waybar
      wofi
      mako
      wl-clipboard
      grim
      slurp
      alacritty
      foot
      pcmanfm
      pavucontrol
    ];

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };
  };
}