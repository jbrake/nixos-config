{ ... }:

{
  services.fprintd.enable = true;

  # Make the important auth surfaces obvious. NixOS defaults fprintAuth to
  # services.fprintd.enable for PAM services, but these are the ones I care
  # about being intentional for this laptop setup.
  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
    "polkit-1".fprintAuth = true;

    # Plasma uses this separate service for the lock screen. Do not enable
    # fingerprint auth on the plain "kde" service; upstream leaves it off so
    # password fallback stays reliable.
    "kde-fingerprint".fprintAuth = true;
  };
}
