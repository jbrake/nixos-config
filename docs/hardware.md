# Hardware Notes

## Framework Laptop 13 — AMD Ryzen AI 300

- DMI version: A9
- CPU: AMD Ryzen AI 9 HX 370
- GPU: integrated Radeon 880M / 890M
- Wi-Fi: MediaTek MT7925 / RZ717 Wi-Fi 7
- Display: 2880x1920 at 120 Hz, normally used at 170% Plasma scale
- Storage: NVMe with an ext4 root filesystem and separate EFI system partition
- Touchpad: PIXA3854; declarative defaults live in the host configuration
- Fingerprint reader: Goodix `27c6:609c`

## Framework Laptop 13 Pro — Intel Core Ultra Series 3

This is the deployed laptop. Its committed hardware file contains the installed
filesystem UUIDs; regenerate it when reinstalling onto a newly formatted disk.
The AMD configuration is retained for reference and is no longer deployed.
Both hardware configurations expose Plasma, GNOME, Cinnamon, COSMIC, and
Hyprland profiles with the shared workstation and Restic configuration.

## Workaround review record

| Workaround | Scope and reason | Retest trigger / removal criterion |
| --- | --- | --- |
| Fingerprint recovery | Explicit settings in each laptop host; missing or unresponsive Goodix reader after idle/resume | Follow [the fingerprint retirement test](fingerprint.md#recovery-switches-and-retirement-test) after kernel or firmware changes. |
| Intel Wi-Fi power saving disabled | Intel host only; previously observed BE211/iwlmld beacon loss | After kernel/wireless-firmware updates, temporarily remove `networking.networkmanager.wifi.powersave = false`, rebuild and reboot, then compare connectivity on the same AP during idle and repeated suspend/resume. Retire the override if the failure no longer reproduces over normal use. |
| SPICE session agent service and autostart mask | VM guests only; session-agent startup failure and duplicate-agent races | After GNOME/SPICE/NixOS module updates, follow [the VM retest procedure](vm-guests.md#retesting-the-spice-workaround). Remove the pair together if upstream session startup works reliably. |

The original failing version combinations for Wi-Fi and SPICE were not recorded.
For each trial, record the date, host/guest and desktop, Nixpkgs revision, kernel,
relevant firmware/package versions, reproduction steps, and result before
removing a workaround. These are local observations, not claims that all newer
versions need the same fixes. None was retired during the 2026-09-05 cleanup.
