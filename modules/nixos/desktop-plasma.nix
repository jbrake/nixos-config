{ pkgs, ... }:

{
  # Touchpad, panel, theme, and other desktop look-and-feel are set by hand
  # in System Settings (see README "First login"). KWin on Wayland keeps them
  # in its own config files; NixOS has no native options for them and this
  # repo stays out of that business on purpose.

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  programs.kdeconnect.enable = true;
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [
        "com.mitchellh.ghostty.desktop"
        "Alacritty.desktop"
        "org.kde.konsole.desktop"
      ];
      KDE = [
        "com.mitchellh.ghostty.desktop"
        "Alacritty.desktop"
        "org.kde.konsole.desktop"
      ];
    };
  };

  environment.systemPackages =
    (with pkgs; [
      haruna
    ])
    ++ (with pkgs.kdePackages; [
      ark
      breeze-gtk
      dolphin
      filelight
      gwenview
      kate
      kcalc
      kdeconnect-kde
      kio-admin
      konsole
      kwalletmanager
      plasma-browser-integration
      plasma-systemmonitor
      spectacle
    ]);
}
