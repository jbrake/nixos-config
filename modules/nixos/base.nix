{
  config,
  pkgs,
  username,
  hostname,
  ...
}:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    description = "Jason Brake";
    home = "/home/${username}";
    createHome = true;
    initialPassword = "changeme";
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "libvirtd"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  security.sudo.wheelNeedsPassword = true;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.fwupd.enable = true;
  services.fstrim.enable = true;

  # mDNS discovery (network printers, KDE Connect hosts, .local names)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.flatpak.enable = true;

  zramSwap.enable = true;

  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    btop
    curl
    dnsutils
    duf
    fastfetch
    git
    glances
    gobuster
    jq
    micro
    nano
    nmap
    openssh
    pciutils
    pv
    ripgrep
    rsync
    unzip
    usbutils
    vim
    wget
    whois
  ];

  # Matches the release current at first install (never installed under 25.11).
  # Do not change after installing.
  system.stateVersion = "26.05";
}
