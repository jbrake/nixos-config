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

This host is planned but not yet provisioned. Its committed hardware file is an
evaluation-only placeholder. `scripts/install-host.sh` will generate and store
the real hardware configuration before the first installation.

It is the replacement for the AMD laptop and exposes the same Plasma, GNOME,
Cinnamon, COSMIC, and Hyprland profiles. All use the shared workstation
configuration and encrypted Restic repository. The Intel laptop receives a new
NAS SSH key; after its first verified backup, the AMD laptop can be erased for
sale.
