{ pkgs, ... }:

# Full Hyprland desktop for physical laptops. Home Manager owns the readable
# Lua configuration and Caelestia shell; this module supplies system plumbing.
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.hyprlock.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  xdg.portal.xdgOpenUsePortal = true;
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "com.mitchellh.ghostty.desktop" ];
      Hyprland = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  environment.systemPackages = with pkgs; [
    adw-gtk3
    nautilus
    papirus-icon-theme
  ];
}
