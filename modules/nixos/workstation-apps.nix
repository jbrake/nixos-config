{ pkgs, ... }:

# Applications and supporting services used on either laptop desktop. Keep
# desktop-specific tools in the individual desktop role modules.
{
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

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

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
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

  environment.systemPackages = with pkgs; [
    alacritty
    brave
    calibre
    capitaine-cursors
    discord
    firefox
    ghostty
    meld
    pavucontrol
    prismlauncher
    proton-vpn
    qbittorrent
    telegram-desktop
    vlc
  ];
}
