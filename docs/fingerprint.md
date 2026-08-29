# Fingerprint Authentication

Fingerprint authentication is deliberately limited to `sudo` and Plasma's
native lock-screen integration.

PAM fingerprint modules run sequentially. Enabling them for interactive login,
SDDM, or polkit can delay the password prompt while fprintd waits for a scan.
Those services therefore remain password-first. Plasma runs its dedicated
`kde-fingerprint` PAM service in parallel with the password prompt. That
fingerprint worker has no timeout or attempt limit, so it remains available for
the lifetime of the lock screen, including across repeated suspend cycles.

The Framework Goodix reader can also become unreliable after suspend. The
module keeps that specific USB device out of runtime autosuspend. On Plasma,
fprintd remains active across sleep so the lock screen's fingerprint worker is
not terminated. Other desktop profiles stop fprintd before sleep so D-Bus can
start it cleanly on the next request.

The AMD AI 300 profile resets the reader's dedicated xHCI controller
immediately before each fprintd activation. This improves reliability after
both suspend and ordinary Plasma locks, including cases where the reader
remains visible to USB but becomes unresponsive. It is a workaround rather
than a complete fix for the underlying hardware or firmware behavior. The
reset runs only when fingerprint authentication is requested.

Other Framework profiles check the reader after resume and reset only when it
is missing until their USB topology has been verified. The controller is
discovered at boot instead of being hard-coded.

Inspect recovery decisions with:

```bash
journalctl -u framework-fingerprint-wake.service
journalctl -u fprintd.service
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
