# nixos-config

Personal NixOS config for Jason's Framework laptops.

This repo is intentionally small. It is not trying to capture every detail from the old install. It gives me a clean NixOS laptop with Plasma, my basic apps, my user account, and a small KDE snapshot for the panel/input/display setup I actually care about.

## Quick Mental Model

NixOS is configured from text files, then rebuilt.

- `flake.nix` is the entry point. It defines the available machines.
- `modules/nixos/base.nix` is shared system setup: user, networking, firmware, Bluetooth, Flatpak, small CLI tools.
- `modules/nixos/desktop-plasma.nix` is the desktop setup: Plasma, audio, graphics, fonts, Steam, and normal desktop apps.
- `modules/nixos/fingerprint.nix` enables the Framework fingerprint reader through fprintd and PAM.
- `hosts/<host>/configuration.nix` is per-laptop setup.
- `hosts/<host>/hardware-configuration.nix` is generated during install for the exact disk/filesystem hardware.
- `home/jason/home.nix` is user-level setup.
- `home/jason/kde/` is the small KDE snapshot.

Normal day-to-day command after editing config:

```bash
./scripts/rebuild.sh
```

## Machines

Use one of these host names:

```text
framework-amd-ai-300
framework-intel-core-ultra
```

`framework-amd-ai-300` is this Framework Laptop 13 with AMD Ryzen AI 300 / HX 370.

`framework-intel-core-ultra` is a placeholder for the incoming Intel Framework 13. If the new laptop is not Core Ultra Series 3, update the nixos-hardware path in `flake.nix`.

## Fresh Install Checklist

Boot the NixOS graphical installer or minimal ISO.

1. Connect Wi-Fi.
2. Partition the disk.
3. Mount the new system at `/mnt`.
4. Mount the EFI partition at `/mnt/boot`.
5. Clone this repo.
6. Run the install script for the right host.
7. Reboot.
8. Change the temporary password.

Example after partitioning and mounting:

```bash
git clone <YOUR_REPO_URL> nixos-config
cd nixos-config
sudo ./scripts/install-host.sh framework-amd-ai-300
```

For the future Intel laptop:

```bash
sudo ./scripts/install-host.sh framework-intel-core-ultra
```

The install script does two important things:

1. Generates `hosts/<host>/hardware-configuration.nix` from the mounted system.
2. Runs `nixos-install --flake .#<host>`.

After first boot, log in as:

```text
user: jason
password: changeme
```

Then immediately run:

```bash
passwd
```

Set up the fingerprint reader:

```bash
fprintd-enroll jason
```

## After Install

Clone the repo somewhere convenient, usually:

```bash
mkdir -p ~/Projects
git clone <YOUR_REPO_URL> ~/Projects/nixos-config
cd ~/Projects/nixos-config
```

Apply system changes:

```bash
./scripts/rebuild.sh
```

Update package inputs:

```bash
./scripts/update-system.sh
```

Check the config without switching:

```bash
nix flake check
```

See previous bootable generations if something goes wrong:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

NixOS also keeps older generations in the boot menu, so a bad rebuild is usually recoverable by rebooting into the previous generation.

## Fingerprint Reader

The repo enables fprintd and wires it into the important PAM services:

- normal login, which SDDM also uses
- `sudo`
- polkit prompts from KDE system settings and admin actions
- Plasma lock screen through KDE's dedicated `kde-fingerprint` PAM service

After a fresh install, enroll your finger:

```bash
fprintd-enroll jason
```

Useful checks:

```bash
fprintd-list jason
fprintd-verify jason
systemctl status fprintd.service
```

`fprintd.service` is D-Bus activated, so it can show as inactive until login, `sudo`, or a check command uses the reader.

To delete enrolled prints and start over:

```bash
fprintd-delete jason
fprintd-enroll jason
```

Fingerprints are stored locally under `/var/lib/fprint`. Do not copy that into this repo; enroll again on each laptop.

Password auth remains available as the fallback. If fingerprint prompts for `sudo` get annoying, set this in `modules/nixos/fingerprint.nix`:

```nix
security.pam.services.sudo.fprintAuth = false;
```

## KDE Snapshot

The KDE snapshot is deliberately narrow. It keeps:

- Plasma panel layout
- pinned launchers
- CPU, memory, and thermal widgets
- mouse/touchpad settings
- display scale/output config
- basic KWin settings
- Brave as the default browser
- small Breeze defaults
- the local thermal monitor plasmoid used by the panel

It intentionally does not keep:

- wallpapers
- distro themes
- full app histories
- browser profiles
- generated GTK theme files
- every random KDE config file

Home Manager copies the KDE snapshot into writable config files once, using this marker:

```text
~/.local/state/nixos-config/kde-snapshot-applied
```

To reapply the KDE snapshot:

```bash
rm ~/.local/state/nixos-config/kde-snapshot-applied
home-manager switch --flake .#jason
```

Or:

```bash
./scripts/apply-kde-snapshot.sh
```

To refresh the repo from the current KDE settings:

```bash
./scripts/snapshot-kde.sh
```

## Adding Apps

Most normal desktop apps live in:

```text
modules/nixos/desktop-plasma.nix
```

Add packages to `environment.systemPackages`.

Small user/dev tools can go in:

```text
home/jason/home.nix
```

Add packages to `home.packages`.

After editing, run:

```bash
./scripts/rebuild.sh
```

If a package name is wrong, the rebuild will fail before changing the running system.

## Current App Set

Desktop apps:

- Alacritty
- Brave
- Discord
- PrismLauncher
- qBittorrent
- Steam
- Telegram
- VLC
- KDE basics: Dolphin, Konsole, Kate, Gwenview, Spectacle, Ark, KCalc, Plasma System Monitor

User/dev tools:

- Node.js and npm
- Python 3
- uv
- unrar

System basics:

- Git
- curl/wget
- ripgrep
- rsync
- btop
- fastfetch
- SSH client
- USB/PCI inspection tools

## What To Edit Most Often

Change installed desktop apps:

```text
modules/nixos/desktop-plasma.nix
```

Change fingerprint login/sudo/polkit behavior:

```text
modules/nixos/fingerprint.nix
```

Change user shell/git/dev tools:

```text
home/jason/home.nix
```

Change laptop-specific hardware options:

```text
hosts/framework-amd-ai-300/configuration.nix
hosts/framework-intel-core-ultra/configuration.nix
```

Change the host list or NixOS/Home Manager input branches:

```text
flake.nix
```

## What Not To Edit By Hand

Usually do not hand-edit:

```text
hosts/<host>/hardware-configuration.nix
flake.lock
```

`hardware-configuration.nix` is generated during install.

`flake.lock` is generated or updated by:

```bash
nix flake update
```

## Git Flow

After changes work:

```bash
git status
git add .
git commit -m "Update NixOS config"
git push
```

Before reinstalling on another machine, push the repo so the installer can clone the latest config.

## Troubleshooting

If a rebuild fails, read the error and fix the config. A failed rebuild normally does not replace your running system.

If the system boots badly after a successful rebuild, reboot and pick an older generation in the boot menu.

If KDE looks wrong, reapply the snapshot:

```bash
./scripts/apply-kde-snapshot.sh
```

If packages are old or missing after a while:

```bash
./scripts/update-system.sh
```

## Notes

- This repo currently targets NixOS `25.11` and Home Manager `25.11` for predictable stable behavior.
- `flake.lock` is not present yet because `nix` is not installed on this machine. Generate it on NixOS with `nix flake update`.
- The first-login password is intentionally temporary. Change it immediately with `passwd`.
