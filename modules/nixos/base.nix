{
  lib,
  pkgs,
  username,
  hostname,
  profile,
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

  # A desktop profile's flake output can differ from the network hostname.
  # Helper scripts use this marker to retain the selected hardware/desktop.
  environment.etc."nixos-config-profile".text = "${profile}\n";

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    # mkDefault so vm-guest.nix can shorten it for the VM login screens.
    description = lib.mkDefault "Jason Brake";
    home = "/home/${username}";
    createHome = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
    ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  environment.shells = [ pkgs.fish ];
  security.sudo.wheelNeedsPassword = true;

  hardware.enableRedistributableFirmware = true;
  services.fstrim.enable = true;

  zramSwap.enable = true;

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
