{ ... }:

{
  services.fprintd.enable = true;

  # Fingerprint auth is deliberately SUDO-ONLY. This mirrors the setup that
  # took real effort to get right on CachyOS (2026-04): PAM modules run
  # sequentially, so pam_fprintd in an interactive login stack makes the
  # password prompt block for 30+ seconds while fprintd waits for a scan.
  #
  # NixOS defaults <service>.fprintAuth = services.fprintd.enable for EVERY
  # PAM service, so everything except sudo must be switched off explicitly.
  #
  # The Plasma lock screen does NOT need pam_fprintd: kscreenlocker talks to
  # fprintd natively over D-Bus (via the separate "kde-fingerprint" PAM
  # service, which nixpkgs manages) in parallel with the password prompt.
  # Leave "kde" and "kde-fingerprint" alone — upstream configures them.
  security.pam.services = {
    # sudo: fprintAuth left at its default (true). NixOS generates
    # "auth sufficient pam_fprintd.so" ahead of pam_unix — scan to auth,
    # or just type the password; either works. Blocking is fine in a
    # terminal that is waiting for input anyway.
    login.fprintAuth = false;
    su.fprintAuth = false;
    sddm.fprintAuth = false;
    sddm-greeter.fprintAuth = false;
    # Keeps GUI polkit dialogs from blocking on a scan (nixpkgs #171136).
    "polkit-1".fprintAuth = false;
  };
}
