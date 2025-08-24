{ config, pkgs, lib, ... }:

{
  users.users.lanna = {
    isNormalUser = true;
    description = "Lanna";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      # Browsers
      firefox
      brave
      
      # Office & Productivity
      libreoffice
      thunderbird
      
      # Media & Entertainment
      spotify
      vlc
      
      # Communication
      zoom-us
      discord
      telegram-desktop
      
      # User-friendly tools
      kdePackages.kate  # Simple text editor
      kdePackages.dolphin-plugins
      kdePackages.ark  # Archive manager
      kdePackages.spectacle  # Screenshot tool
      
      # Photo management
      digikam
      gwenview
    ];
  };
}