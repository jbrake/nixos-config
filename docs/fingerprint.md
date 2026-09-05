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

## Recovery switches and retirement test

`modules/nixos/fingerprint.nix` enables ordinary fprintd/PAM integration.
Recovery is selected explicitly in each laptop's `configuration.nix`:

| Setting | Default for new hosts | Retained AMD | Deployed Intel |
| --- | --- | --- | --- |
| `jbrake.frameworkFingerprint.resetMode` | `"disabled"` | `"before-use"` | `"when-missing"` |
| `jbrake.frameworkFingerprint.keepAwake` | `false` | `true` | `true` |
| `jbrake.frameworkFingerprint.stopBeforeSleep` | `false` | `true` | `true` |

`resetMode = "disabled"` removes controller discovery/recovery services and the
fprintd pre-start reset, without disabling fingerprint authentication. The
`stopBeforeSleep` switch never stops Plasma's lock-screen worker. `"always"`
remains available for a host that needs recovery after every resume.

A reset unbinds the **entire xHCI controller**, not just the fingerprint device.
The code verifies the driver's identity and discovers the controller from the
reader; it does not prove that the controller is dedicated. Before enabling a
reset mode on new hardware, inspect `lsusb -t` and the corresponding sysfs
paths for other devices on that controller. `"when-missing"` reduces the number
of resets; it does not make a shared controller safe to reset. The AMD policy
records an earlier observation that its controller was dedicated. Recheck after
hardware/topology changes.

After a kernel or firmware update, retest one workaround at a time:

1. Record the hostname, desktop, date, `uname -r`, `nixos-version`, firmware
   versions from `fwupdmgr get-devices`, and the Goodix entry in `lsusb -t`.
   The original failing kernel/firmware versions were not recorded, so do not
   infer a fixed version from these workarounds' presence.
2. In that host's configuration, set `resetMode = "disabled"`, leaving the
   other two switches unchanged. Build for the next boot with
   `sudo nixos-rebuild boot --flake ".#$(cat /etc/nixos-config-profile)"`, then
   reboot. Keep the previous generation available during the trial.
3. Verify enrollment still works, then test `fprintd-verify jason` after a cold
   boot, ordinary lock/idle, and at least five suspend/resume cycles. On Plasma,
   also test repeated lock-screen fingerprint unlocks. Check password fallback
   and the fprintd journal. Do not delete enrollments as part of this test.
4. If reliable during normal use, keep resets disabled. Repeat separately with
   `stopBeforeSleep = false`, then `keepAwake = false`. If a symptom returns,
   restore the relevant setting and record the reproduction and versions here.
5. After a sustained successful trial, remove that host's unnecessary override.
   Defaults leave recovery off. Retire shared workaround code only after every
   retained host that needs it has been accounted for.

No hardware retirement trial was performed during the 2026-09-05 configuration
cleanup; both hosts retain their previous recovery policies.
