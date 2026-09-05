{ pkgs, ... }:

{
  # Home Manager declares selected theme/touchpad settings in home/jason/home.nix;
  # the AMD host also supplies touchpad defaults. Other preferences remain
  # editable in System Settings and are saved by the desktop-state capsules.

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
