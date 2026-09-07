# Switching Desktop Environments

Both Framework laptops expose five profiles. Replace `HOST` with
`framework-amd-ai-300` or `framework-intel-core-ultra`:

```text
HOST             Plasma
HOST-gnome       GNOME
HOST-cinnamon    Cinnamon
HOST-cosmic      COSMIC
HOST-hyprland    Hyprland with Caelestia
```

Both share the same personal files, applications, hardware, backup,
containers, and virtualization. A boot-time service keeps only
desktop-sensitive state in separate capsules:

```text
~/.local/state/desktop-profiles/plasma
~/.local/state/desktop-profiles/gnome
~/.local/state/desktop-profiles/cinnamon
~/.local/state/desktop-profiles/cosmic
~/.local/state/desktop-profiles/hyprland
```

The capsules are root-owned and are included in the existing encrypted Restic
home backup.

## Local Capsules and Restic

These are two separate safety layers:

| Local desktop capsule | Restic backup |
| --- | --- |
| Runs automatically during every completed desktop switch | Runs daily or when switching with `--backup` |
| Saves desktop-sensitive settings | Saves nearly the entire home directory |
| Keeps the latest state for each desktop | Keeps historical snapshots |
| Stays on the laptop for quick switching | Is encrypted and stored on the NAS for recovery |

A normal switch does not contact the NAS. Restic does not control desktop
switching; it also backs up the local capsules during the next home snapshot.

## First-Time Setup

Apply the current configuration once before the first switch:

```bash
./scripts/rebuild.sh
```

This installs the boot-time state service and records the active desktop. It
does not move any files during this first activation.

## Switch Desktops

Schedule any desktop for the next boot:

```bash
sudo ./scripts/switch-desktop.sh gnome
sudo ./scripts/switch-desktop.sh cinnamon
sudo ./scripts/switch-desktop.sh cosmic
sudo ./scripts/switch-desktop.sh hyprland
```

A normal switch follows this sequence:

1. Build the target desktop for the next boot without changing the live session.
2. Close applications and reboot normally.
3. Save the current desktop's local capsule before graphical login starts.
4. Restore the target's latest capsule, or start it clean on its first use.

Personal files and shared application profiles remain in place throughout.

Return to the last Plasma state:

```bash
sudo ./scripts/switch-desktop.sh plasma
```

Every later switch restores the target desktop where it was left.

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
desktop automatically. Both helpers refuse an explicit profile that would
change the active Framework desktop live.

## Shared and Isolated State

These remain shared and are never rolled backward by a desktop switch:

- Documents, downloads, pictures, and repositories
- Brave Origin, Discord, Telegram, Steam, and PrismLauncher
- Codex, Claude, SSH, Git, and shell data

These are saved separately for all five desktops:

- Plasma panels, KWin, KDE applications, KDE Connect, and KDE Wallet
- GNOME dconf, Shell state, Nautilus, GNOME Online Accounts, and GNOME Keyring
- Cinnamon dconf, panels, applets, Nemo, Online Accounts, and keyring
- COSMIC panels, tiling, applications, themes, Files, and keyring
- Caelestia wallpaper palette, shell state, and keyring
- GTK, Qt, cursor, icon, portal, and desktop theme state

Credential stores are isolated with their desktop. An application may require
authentication the first time it runs there, then remember it on later returns.

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
- Tiling Shell for optional snap layouts and window tiling
- Clipboard Indicator for searchable clipboard history
- Vitals for system information in the top panel
- Caffeine for temporarily preventing screen blanking and suspend

Each extension can be turned off independently in Extension Manager. Tiling
Shell also exposes its layouts and behavior from its panel indicator. The dock
favorites are Brave Origin, Files, Ghostty, Discord, and Steam.

GNOME also starts with centered windows, four workspaces, a weekday clock,
battery percentage, the purple accent color, window control buttons, disabled
hot corners, Files in list view, directories sorted first, and Bluefin-style
window-switching shortcuts.

The touchpad matches the Plasma defaults where GNOME exposes an equivalent:
tap-to-click and disable-while-typing are off, natural two-finger scrolling is
on, and physical click-finger behavior is used. Plasma's independent
`ScrollFactor=0.3` has no supported GNOME equivalent and is intentionally not
approximated.

The adapted defaults are based on Bluefin's Apache-2.0 licensed
[GNOME configuration](https://github.com/projectbluefin/common/blob/ed4aa87ad93b1e5ae2501d5b62a8dc5063c45a52/system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override).

## Hyprland Defaults

The laptop Hyprland profile uses the native NixOS and Home Manager modules with
UWSM, SDDM, portals, keyring integration, idle locking, and a readable Lua
configuration. [Caelestia](https://github.com/caelestia-dots/shell) supplies the
bar, launcher, notifications, lock screen, wallpaper picker, and dynamic color
scheme through its official flake; no external installer runs.

Start with these keys:

```text
Super or Super+Space   launcher, settings, wallpapers, and schemes
Super+/                complete graphical shortcut guide
Super+Enter            Ghostty
Super+B                Brave Origin
Super+E                Files
Super+Q                close the focused window
Super+1 through 9      change workspace
Ctrl+Alt+Delete        session and power menu
```

The first login selects a bundled NixOS wallpaper and derives matching
Hyprland, Caelestia, GTK, and live Ghostty terminal colors. Three starter
wallpapers appear under `~/Pictures/Wallpapers`; adding images there makes them
available to the picker. Wallpaper and generated palette state return with the
Hyprland capsule.

The touchpad matches Plasma: tap-to-click and tap-and-drag are off, natural
scrolling and finger-based physical clicking are on, and the scroll factor is
`0.3`. A three-finger horizontal swipe changes workspaces. The screen locks
after 5 minutes idle, powers off after 10, and suspends after 20.

## Cinnamon and COSMIC Defaults

Cinnamon uses the native NixOS Cinnamon module with LightDM, Nemo, portals,
keyring integration, and its standard applications. Native GSettings defaults
match the Plasma touchpad where possible: tap-to-click, tap-and-drag, and
disable-while-typing are off; natural two-finger scrolling and finger-based
physical clicking are on.

COSMIC uses the native NixOS COSMIC module with its Wayland compositor,
greeter, panel, tiling, settings, applications, portals, and Cosmic Files.
COSMIC is still evolving and stores settings in its own versioned files, so
appearance and touchpad choices remain interactive and are preserved by the
COSMIC capsule rather than declaring unstable internal file formats.

Ghostty is the preferred terminal and each desktop's native file manager is the
default. Shared workstation applications remain identical across profiles.

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

On an interrupted transition, booting its target retries the saved destination;
booting its source restores the saved source capsule. If restoration already
published its current marker, the next boot clears the completed journal and
then honors the selected desktop. An unrelated third desktop is rejected while
the journal remains unresolved.

CI exercises copy failures during save/restore, interruption immediately after
publishing the current marker, retrying the target, and returning to the source.
It checks capsule contents, home ownership/permissions, and shared personal
files using temporary homes under fakeroot. These tests cover process failures;
they do not establish filesystem durability after sudden power loss or replace
the encrypted Restic backup.

## Clean Recovery or Reinstallation

For a fresh disk installation, select any laptop output and follow the
[backup recovery guide](backup-recovery.md). To migrate into GNOME without
restoring Plasma state, restore the old snapshot into
`/mnt/restic-restore`, preview the curated copy, and apply it:

```bash
./scripts/restore-gnome-home.sh
sudo ./scripts/restore-gnome-home.sh --apply
```

The restore script keeps the fresh repository and copies personal and selected
application data without bulk-copying `.config` or `.local/share`.

## Intel Plasma unstable retest (September 6, 2026)

The full unstable package set at `c043004d1c6985732bcc1cbc5a9c9aecbbb4e0f0`
(Plasma 6.7.4, kernel 7.2.3; generation 64) still showed poor desktop
responsiveness in Jason's hardware test. He returned to stable generation 63
(Plasma 6.6.6), and the flake inputs were restored to NixOS 26.05. Keep stable
as the normal laptop package set; this retest does not identify the specific
component responsible or establish how Hyprland performs on the laptop.

On September 7, the Nixarchy laptop trial generation 66 was removed and stable
generation 65 was selected as the boot default. The normal rebuild/update target
is `framework-intel-core-ultra` (Plasma 6.6.6 on NixOS 26.05); Nixarchy remains
an explicitly selected experimental profile. Keep `nixpkgs` on `nixos-26.05`
and Home Manager on `release-26.05` when updating inputs.

## Nixarchy laptop trial

The Intel laptop also exposes `framework-intel-core-ultra-nixarchy`. It uses
Nixarchy's pinned unstable Nixpkgs and Home Manager, matching the working VM.
The ordinary Plasma profile and other desktop profiles remain on stable 26.05.
Hardware configuration, backups, applications and Podman are shared modules;
there are no desktop-package backports or local patches to Nixarchy.

```bash
sudo ./scripts/switch-desktop.sh nixarchy --backup
# Reboot when ready. To return afterwards:
sudo ./scripts/switch-desktop.sh plasma
```

The Nixarchy session is selected by default. `Super + Space` opens its menu;
`Super + K` shows shortcuts. Terminal, Hyprland, Omarchy theme and shell state
are isolated with the desktop, alongside the existing GTK, Qt and keyring
state. Home Manager seeds the desktop; Arch's first-login provisioning is
marked complete so it cannot rewrite shared application defaults or XDG paths.

Install, Remove and system-update menu actions are hidden on the laptop because
they select a rebuild target by hostname, which would select stable Plasma in
this flake. Declare packages here and use `scripts/rebuild.sh` to apply them.
Themes and other desktop settings remain interactive. Nixarchy itself is pinned
to an explicit commit; change its input URL deliberately to update it.

Before the first trial, install a fresh stable boot generation from this tree,
then schedule Nixarchy. That stable fallback contains the updated state-restoration
code and can restore Plasma after a Nixarchy boot. For recovery, select that
fresh stable generation, rather than an older generation whose state service
does not recognize the new desktop. No live desktop change or automatic reboot
is needed to prepare these two boot entries.
