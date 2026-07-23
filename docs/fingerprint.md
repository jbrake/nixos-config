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
resume, a NixOS service waits two seconds before recovery. The AMD AI 300
profile resets the reader's dedicated xHCI controller after every wake because
the reader can remain visible to USB while internally unresponsive. Other
Framework profiles reset only when the reader is missing until their USB
topology has been verified. The controller is discovered at boot instead of
being hard-coded.

Recovery is ordered before fprintd, preventing Plasma's immediate D-Bus request
from opening the reader while recovery is still in progress.

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
