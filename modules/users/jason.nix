{ config, pkgs, lib, ... }:

{
  users.users.jason = {
    isNormalUser = true;
    description = "Jason";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "podman" ];
    packages = with pkgs; [
      brave
      protonvpn-gui
      telegram-desktop
      vscode
      discord
      prismlauncher
      boxbuddy
      distrobox
      mediawriter
    ];
  };
}