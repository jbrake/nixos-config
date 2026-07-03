# nixos-config

Personal NixOS config for Jason's Framework laptops.

This repo is intentionally small. It is not trying to capture every detail from the old install. It gives me a clean NixOS laptop with Plasma, my basic apps, my user account, and a small KDE snapshot for the panel/input/display setup I actually care about.

## Quick Mental Model

NixOS is configured from text files, then rebuilt. The Nix files are the source of truth; scripts in this repo are only optional wrappers around standard Nix commands.

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
sudo nixos-rebuild switch --flake .#$(hostname)
```

Optional wrapper. It uses the current system hostname when it matches a host in this repo:

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
6. Run the install commands for the right host.
7. Reboot.
8. Change the temporary password.

Example after partitioning and mounting:

```bash
git clone <YOUR_REPO_URL> nixos-config
cd nixos-config
host=framework-amd-ai-300
nix --extra-experimental-features "nix-command flakes" flake lock --flake "path:$PWD"
sudo nixos-generate-config --root /mnt --show-hardware-config > "hosts/$host/hardware-configuration.nix"
sudo nixos-install --root /mnt --flake "path:$PWD#$host" --no-root-passwd
sudo mkdir -p /mnt/home/jason/Projects
sudo cp -a . /mnt/home/jason/Projects/nixos-config
sudo chown 1000:100 /mnt/home/jason /mnt/home/jason/Projects
sudo chown -R 1000:100 /mnt/home/jason/Projects/nixos-config
```

For the future Intel laptop, run the same commands with this host value:

```bash
host=framework-intel-core-ultra
```

If you prefer the helper script, it runs those same bootstrap steps:

```bash
sudo ./scripts/install-host.sh framework-amd-ai-300
```

For the future Intel laptop:

```bash
sudo ./scripts/install-host.sh framework-intel-core-ultra
```

Those bootstrap steps do four important things:

1. Generates `hosts/<host>/hardware-configuration.nix` from the mounted system.
2. Creates `flake.lock` so the exact inputs used for install are pinned.
3. Runs `nixos-install --flake .#<host>`.
4. Copies the generated repo to `/mnt/home/jason/Projects/nixos-config` so it is ready after reboot.

The host name argument is required on purpose. It avoids accidentally installing the AMD config on the future Intel laptop, or the other way around.

The script skips setting a separate root password. Use the `jason` account and `sudo` after first boot.

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

Use the repo that the installer copied into your home directory:

```bash
cd ~/Projects/nixos-config
```

Commit the generated hardware config once the system is working:

```bash
git status
git add flake.lock hosts/$(hostname)/hardware-configuration.nix
git commit -m "Add hardware config for $(hostname)"
git push
```

If you skipped the install script copy or intentionally want a fresh clone later:

```bash
mkdir -p ~/Projects
git clone <YOUR_REPO_URL> ~/Projects/nixos-config
```

Apply system changes:

```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```

Update package inputs:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#$(hostname)
```

Check the current host config without switching:

```bash
sudo nixos-rebuild build --flake .#$(hostname)
```

`nix flake check` evaluates every host in this repo. It will fail while another laptop still has the placeholder `hardware-configuration.nix`.

See previous bootable generations if something goes wrong:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

NixOS also keeps older generations in the boot menu, so a bad rebuild is usually recoverable by rebooting into the previous generation.

## Fingerprint Reader

The repo enables fprintd, but fingerprint auth in PAM is **sudo-only** on purpose:

- `sudo`: scan a finger, or just type the password — either works.
- Login, SDDM, and polkit dialogs: password only. PAM runs modules in
  sequence, so putting fingerprint there makes the password prompt hang for
  30+ seconds waiting for a scan (this was learned the hard way on CachyOS).
- Plasma lock screen: fingerprint still works. kscreenlocker talks to fprintd
  natively over D-Bus in parallel with the password prompt, no PAM needed.

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
- mouse cursor settings
- touchpad behavior via the per-device `[Libinput]` sections in `kcminputrc`
  (this is what KWin actually reads on Wayland; `services.libinput` only
  affects X11). The sections are keyed to the exact touchpad model, so a new
  machine ignores them — set touchpad prefs once in System Settings there,
  then run `./scripts/snapshot-kde.sh` to capture its section too.
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
- Bottles
- Brave
- Calibre
- Discord
- Firefox
- Haruna
- Meld
- PrismLauncher
- Proton VPN
- qBittorrent
- Steam
- Telegram
- VLC
- KDE basics: Dolphin, Konsole, Kate, Gwenview, Spectacle, Ark, KCalc, Filelight, KWalletManager, Plasma System Monitor

User/dev tools:

- claude-code and codex CLIs
- Node.js, including npm
- Python 3
- uv
- unrar

System basics:

- Git
- curl/wget
- ripgrep
- rsync
- btop, glances, duf, pv
- fastfetch
- micro, nano, vim
- nmap, gobuster, whois, dig
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

`flake.lock` is generated by the install script or:

```bash
nix flake lock
```

It is updated by `./scripts/update-system.sh`.

Without the helper script:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#$(hostname)
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

- This repo targets `nixos-unstable`: it matches the Plasma 6.7 already in
  use and carries the freshest kernel/firmware for the Panther Lake 13 Pro.
  `flake.lock` pins the exact revision, so rebuilds are reproducible; a bad
  `nix flake update` is undone by rebooting into the previous generation. If
  unstable ever gets tiresome, repoint `nixpkgs` at `nixos-26.05`.
- The first-login password is intentionally temporary. Change it immediately with `passwd`.
