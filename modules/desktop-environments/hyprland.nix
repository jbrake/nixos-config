{ config, lib, pkgs, ... }:

with lib;

{
  options.desktops.hyprland = {
    enable = mkEnableOption "Hyprland wayland compositor";
  };

  config = mkIf config.desktops.hyprland.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    environment.systemPackages = with pkgs; [
      waybar
      wofi
      mako
      swaylock
      swayidle
      wl-clipboard
      grim
      slurp
      alacritty
      kdePackages.dolphin
      pavucontrol
    ];

    # Prefer Hyprland portal for screen sharing/pipewire integration
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    };
  };
}
