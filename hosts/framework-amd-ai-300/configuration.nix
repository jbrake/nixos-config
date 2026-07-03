{ lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Touchpad defaults for this machine's PIXA3854 pad. KDE's config cascade
  # reads /etc/xdg/kcminputrc as the system default; anything changed later
  # in System Settings is written to ~/.config/kcminputrc and wins. Purely
  # declarative defaults, GUI stays fully functional. Section keys are the
  # device's vendor/product ids (0x093A/0x0274) in decimal.
  environment.etc."xdg/kcminputrc".text = ''
    [Libinput][2362][628][PIXA3854:00 093A:0274 Touchpad]
    ClickMethod=2
    DisableWhileTyping=false
    NaturalScroll=true
    ScrollFactor=0.3
    TapToClick=false
  '';

  environment.systemPackages = with pkgs; [
    mesa-demos
    radeontop
  ];
}
