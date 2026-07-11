_:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    fwupd.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
    flatpak.enable = true;
    tailscale = {
      enable = true;
      openFirewall = true;
    };

    # Local discovery for printers, KDE Connect, and .local hosts.
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
