{ config, pkgs, lib, ... }:

{
  # Networking
  networking.networkmanager.enable = true;

  # Time zone and locale
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Sound
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Framework laptop specific
  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = true;

  # Fingerprint
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = lib.mkDefault true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.sddm.fprintAuth = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Core programs
  programs.firefox.enable = true;
  programs.steam.enable = true;

  # Virtualization
  virtualisation.podman.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # VPN
  services.tailscale.enable = true;

  # Essential system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    htop
    neofetch
    dig
    usbutils
    gparted
    python3
    nodejs_20
  ];
}