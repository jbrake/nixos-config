{ pkgs, ... }:

{
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";
  services.libinput = {
    enable = true;
    touchpad = {
      accelProfile = "adaptive";
      accelSpeed = "0";
      clickMethod = "clickfinger";
      disableWhileTyping = false;
      leftHanded = false;
      middleEmulation = false;
      scrollMethod = "twofinger";
      tapping = false;
      naturalScrolling = true;
      sendEventsMode = "enabled";
    };
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  programs.kdeconnect.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  fonts = {
    packages = with pkgs; [
      awesome-terminal-fonts
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      monospace = [ "DejaVu Sans Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  environment.systemPackages =
    (with pkgs; [
      alacritty
      bottles
      brave
      calibre
      capitaine-cursors
      discord
      firefox
      haruna
      meld
      pavucontrol
      prismlauncher
      protonvpn-gui
      qbittorrent
      telegram-desktop
      vlc
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
