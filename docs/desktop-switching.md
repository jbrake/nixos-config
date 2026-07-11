# Switching Between Plasma and GNOME

The AMD laptop has two NixOS outputs for the same hardware:

```text
framework-amd-ai-300         Plasma
framework-amd-ai-300-gnome   GNOME
```

Both share the same personal files, applications, hardware, backup,
containers, and virtualization. A boot-time service keeps only
desktop-sensitive state in separate capsules:

```text
~/.local/state/desktop-profiles/plasma
~/.local/state/desktop-profiles/gnome
```

The capsules are root-owned and are included in the existing encrypted Restic
home backup.

## First-Time Setup

Apply the current Plasma configuration once before the first switch:

```bash
./scripts/rebuild.sh
```

This installs the boot-time state service and records Plasma as the current
desktop. It does not move any files during this first activation.

## Switch Desktops

Schedule GNOME for the next boot:

```bash
sudo ./scripts/switch-desktop.sh gnome
```

Close applications and reboot normally. Before GDM starts, the service saves
the current Plasma state and restores the last GNOME state. GNOME starts clean
the first time because it has no saved capsule yet.

Return to the last Plasma state:

```bash
sudo ./scripts/switch-desktop.sh plasma
```

After using GNOME again, its latest state is saved before Plasma starts. Every
later switch restores the target desktop where it was left.

Useful optional flags are:

```bash
sudo ./scripts/switch-desktop.sh gnome --backup
sudo ./scripts/switch-desktop.sh gnome --backup --reboot
```

`--backup` waits for a Restic backup before building the target. `--reboot`
reboots immediately after a successful build, so close applications before
using it.

Always use the switch script for routine desktop changes. It builds the target
with `nixos-rebuild boot` so no display manager or home state changes under the
running graphical session. After the reboot, `rebuild.sh` and
`update-system.sh` read `/etc/nixos-config-profile` and retain the active
desktop automatically.

## Shared and Isolated State

These remain shared and are never rolled backward by a desktop switch:

- Documents, downloads, pictures, and repositories
- Brave, Discord, Telegram, Steam, and PrismLauncher
- Codex, Claude, SSH, Git, and shell data

These are saved separately for Plasma and GNOME:

- Plasma panels, KWin, KDE applications, KDE Connect, and KDE Wallet
- GNOME dconf, Shell state, Nautilus, GNOME Online Accounts, and GNOME Keyring
- GTK, Qt, cursor, icon, portal, and desktop theme state

Because KDE Wallet and GNOME Keyring are separate, an application may require
authentication the first time it runs under a desktop. That desktop remembers
the credentials on later returns.

## GNOME Defaults

The GNOME laptop profile uses native NixOS GSettings schema overrides for a
Bluefin-inspired starting point. These are defaults, not locks: changes made in
GNOME Settings, Tweaks, or Extension Manager are stored in the GNOME capsule
and return with it.

The default enabled extensions are:

- Dash to Dock with Bluefin's bottom, fixed, dynamically transparent styling
- Blur My Shell for the dock only
- AppIndicator for application tray icons
- GSConnect for phone integration

Caffeine is installed but left disabled for optional use in Extension Manager.
The dock favorites are Brave, Files, Ghostty, Discord, and Steam.

GNOME also starts with centered windows, four workspaces, a weekday clock,
battery percentage, the purple accent color, window control buttons, disabled
hot corners, directories sorted first, and Bluefin-style window-switching
shortcuts.

The touchpad matches the Plasma defaults where GNOME exposes an equivalent:
tap-to-click and disable-while-typing are off, natural two-finger scrolling is
on, and physical click-finger behavior is used. Plasma's independent
`ScrollFactor=0.3` has no supported GNOME equivalent and is intentionally not
approximated.

The adapted defaults are based on Bluefin's Apache-2.0 licensed
[GNOME configuration](https://github.com/projectbluefin/common/blob/ed4aa87ad93b1e5ae2501d5b62a8dc5063c45a52/system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override).

## Status and Troubleshooting

Show the active NixOS output and desktop-state service:

```bash
cat /etc/nixos-config-profile
systemctl status desktop-state-activate.service
```

If state activation fails, the graphical login stays stopped to avoid mixing
desktop state. Use `Ctrl-Alt-F3`, log in, and inspect:

```bash
journalctl -u desktop-state-activate.service -b
```

Booting the previous NixOS generation is safe. An interrupted transition is
either completed for the target generation or restored back to the source
desktop from its saved capsule.

## Clean Recovery or Reinstallation

For a fresh disk installation, select either NixOS output and follow the
[backup recovery guide](backup-recovery.md). To migrate into GNOME without
restoring Plasma state, restore the old snapshot into
`/mnt/restic-restore`, preview the curated copy, and apply it:

```bash
./scripts/restore-gnome-home.sh
sudo ./scripts/restore-gnome-home.sh --apply
```

The restore script keeps the fresh repository and copies personal and selected
application data without bulk-copying `.config` or `.local/share`.
