# Fingerprint Authentication

Fingerprint authentication is deliberately limited to `sudo` and Plasma's
native lock-screen integration.

PAM fingerprint modules run sequentially. Enabling them for interactive login,
SDDM, or polkit can delay the password prompt while fprintd waits for a scan.
Those services therefore remain password-first. The Plasma lock screen talks to
fprintd through KDE's dedicated integration and does not need the same PAM
configuration.

The Framework Goodix reader can also become unreliable after suspend. The
module keeps that specific USB device out of runtime autosuspend and stops
fprintd before sleep so D-Bus can start it cleanly on the next request. After
resume, a NixOS service waits two seconds and checks whether the reader
returned. It normally does nothing; if the reader is missing, it resets the
saved xHCI controller and refreshes fprintd. The controller is discovered at
boot instead of being hard-coded, so the same module works across Framework
profiles.

Inspect recovery decisions with:

```bash
journalctl -u framework-fingerprint-wake.service
```

Useful commands:

```bash
fprintd-enroll jason
fprintd-list jason
fprintd-verify jason
fprintd-delete jason
```

Fingerprint enrollments live under `/var/lib/fprint`; they are machine state,
not part of this repository or the home-directory backup.
