# nixos-config

NixOS for Jason's Framework laptops. One flake, two machines:

| Host | Machine |
|---|---|
| `framework-amd-ai-300` | Framework 13, AMD Ryzen AI 9 HX 370 |
| `framework-intel-core-ultra` | Framework 13 Pro, Intel (Panther Lake) |

Philosophy: the system (packages, services, users, fingerprint, virtualization)
is fully declarative. Desktop look-and-feel (panel, theme, touchpad) is set
once by hand in System Settings — Plasma owns those files at runtime and
pretending otherwise gets hacky. The one-time checklist is below.

## Repo layout

```
flake.nix                        inputs (nixos-unstable) + the two hosts
hosts/<host>/configuration.nix   per-machine tweaks (kernel, microcode, gpu tools)
hosts/<host>/hardware-configuration.nix   generated at install; placeholder until then
modules/nixos/base.nix           user, networking, nix settings, CLI tools, libvirt
modules/nixos/desktop-plasma.nix Plasma 6 + SDDM, audio, fonts, Steam, desktop apps
modules/nixos/fingerprint.nix    fprintd; fingerprint on sudo ONLY (see below)
home/jason/home.nix              git identity, fish, dev tools, alacritty config
scripts/                         optional wrappers around standard nix commands
```

## Install a machine

Everything is wiped. Back up first: `~/.ssh`, `~/Documents`, `~/.claude`,
`~/.config/BraveSoftware`, `~/.local/share/TelegramDesktop`, Calibre library,
PrismLauncher instances.

**1. Boot the NixOS ISO** (graphical or minimal, either works) from USB.
Keep a second USB with another distro as an escape hatch.

**2. Connect Wi-Fi** (NetworkManager applet on the graphical ISO, `nmtui` on minimal).

**3. Partition and mount.** Example for a blank NVMe disk — 1 GB EFI + the
rest ext4, no encryption, no disk swap (the config uses zram):

```bash
sudo -i
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1GB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root ext4 1GB 100%
mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/BOOT /mnt/boot
```

**4. Clone and install** (still as root, pick the right host name):

```bash
git clone https://github.com/jbrake/nixos-config.git
cd nixos-config
./scripts/install-host.sh framework-amd-ai-300
```

The script generates `hardware-configuration.nix` from the mounted disk,
locks the flake, runs `nixos-install`, and copies the repo to
`/home/jason/Projects/nixos-config` on the new system.

**5. Reboot.** Log in as `jason` / `changeme`.

## First boot

Terminal part:

```bash
passwd                                   # change the temporary password NOW
fprintd-enroll jason                     # enroll a finger, then test:
sudo -k; sudo true                       # scan OR just type password — both must work
cd ~/Projects/nixos-config
git remote set-url origin git@github.com:jbrake/nixos-config.git
git add hosts/*/hardware-configuration.nix flake.lock
git commit -m "Add hardware config for $(hostname)" && git push
```

One-time System Settings checklist (~5 min):

- **Colors & Themes**: Global Theme → Breeze Dark. Colors → accent color →
  custom → `184,117,220` (the purple). Cursor → Capitaine (already installed).
- **Display**: scale 170% on the 2.8K panel.
- **Touchpad**: already set on the AMD host (declared as system defaults in
  its `configuration.nix` — KDE reads `/etc/xdg/kcminputrc` natively). On a
  new machine, set by hand first (natural scrolling ON, tap-to-click OFF,
  disable-while-typing OFF, right-click = two-finger press, scroll speed
  low), then copy the `[Libinput]...` section from `~/.config/kcminputrc`
  into that host's `configuration.nix` the same way.
- **Panel**: move/keep panel at bottom; add widgets: pager, CPU usage (pie),
  memory usage (pie), Thermal Monitor (install via Add Widgets → Get New
  Widgets → search "Thermal Monitor" by Oliver Beard), battery percentage
  (in system tray settings), 24-hour clock. Pin your apps to the task bar.
- **Default apps**: browser → Brave.
- Log into Brave, Steam, Discord, Telegram, Proton VPN; pair KDE Connect.

## Day to day

Edit config, then apply (a failed build never touches the running system):

```bash
sudo nixos-rebuild switch --flake ~/Projects/nixos-config
```

Update everything (do it when you feel like it — daily is fine):

```bash
cd ~/Projects/nixos-config
nix flake update && sudo nixos-rebuild switch --flake .
git commit -am "Update flake inputs" && git push
```

Something broke after an update? Reboot, pick the previous generation in the
boot menu, then `git checkout flake.lock` to stay on the old versions.

Add an app: put it in `environment.systemPackages` in
`modules/nixos/desktop-plasma.nix` (GUI) or `modules/nixos/base.nix` (CLI),
rebuild. Search names at <https://search.nixos.org/packages>.

`scripts/rebuild.sh` and `scripts/update-system.sh` are the same commands
with a wrong-host guard. Use them or don't.

## Fingerprint: why sudo-only

PAM runs modules in sequence, so putting fingerprint in login/SDDM/polkit
makes every password prompt hang ~30s waiting for a scan (learned the hard
way on CachyOS). So `modules/nixos/fingerprint.nix` enables it for `sudo`
only — scan or type, either works. The Plasma lock screen still does
fingerprint natively over D-Bus without PAM. Don't "fix" this by enabling
fprintAuth more broadly.

Prints live in `/var/lib/fprint` (never in this repo). Re-enroll per machine.
`fprintd-list jason` / `fprintd-verify jason` to check; `fprintd-delete jason`
to start over.

## Notes

- Pinned to `nixos-unstable` for fresh packages (Plasma point releases land
  in days, major bumps 1–3 weeks). `flake.lock` makes it reproducible; the
  boot menu makes it safe. If it ever annoys, repoint `nixpkgs` in
  `flake.nix` at a stable release.
- Don't hand-edit `hardware-configuration.nix` or `flake.lock`.
- `docs/current-machine.md` has the old CachyOS hardware notes for reference.
