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

**1. Boot the NixOS graphical ISO** from USB. Keep a second USB with another
distro as an escape hatch.

**2. Run the installer** (Calamares). Choose: erase disk, no encryption,
Plasma desktop, no swap (the config uses zram). Create user `jason` with
your real password — it carries over. Reboot into the fresh desktop.

**3. Adopt this config.** Connect Wi-Fi, open Konsole:

```bash
mkdir -p ~/Projects && cd ~/Projects
nix-shell -p git
git clone https://github.com/jbrake/nixos-config.git
cd nixos-config
cp /etc/nixos/hardware-configuration.nix hosts/framework-amd-ai-300/   # pick the right host
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild boot --flake .#framework-amd-ai-300
reboot
```

(`nixos-rebuild boot` swaps the system at the next reboot instead of live,
which is cleaner when replacing the desktop you're sitting in. The NIX_CONFIG
bit is only needed this once — the config enables flakes permanently.)

That's it — you reboot into the real system.

<details>
<summary>Alternative: install straight from the ISO, no interim desktop</summary>

Faster once you know the drill: boot any NixOS ISO, connect Wi-Fi, then as
root — partition and mount at `/mnt` (1 GB EFI vfat labeled `BOOT` at
`/mnt/boot`, rest ext4 labeled `nixos` at `/mnt`), then:

```bash
git clone https://github.com/jbrake/nixos-config.git
cd nixos-config
./scripts/install-host.sh framework-amd-ai-300
```

The script generates the hardware config, locks the flake, and installs.
Because no installer wizard asks for a password in this flow, you log in as
`jason` / `changeme` and must run `passwd` immediately.
</details>

## First boot

Terminal part:

```bash
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

Add an app: put it in `environment.systemPackages` in
`modules/nixos/desktop-plasma.nix` (GUI) or `modules/nixos/base.nix` (CLI),
rebuild. Search names at <https://search.nixos.org/packages>.

## Updating everything

There is no `pacman -Syu` equivalent that mutates packages in place. Instead,
`flake.lock` pins the exact nixpkgs revision the whole system builds from.
Updating = move that pin to the latest nixos-unstable, rebuild, reboot-free:

```bash
cd ~/Projects/nixos-config
nix flake update                          # 1. move the pin (updates flake.lock)
sudo nixos-rebuild switch --flake .       # 2. rebuild + activate everything
git commit -am "Update flake inputs" && git push   # 3. record what you're running
```

That updates every package, the kernel (active after next reboot), Plasma,
drivers — the entire system, atomically. Do it when you feel like it; daily
is fine, weekly is fine, before installing something new is a good habit.

Or the same thing as one command:

```bash
./scripts/update-system.sh
```

**Firmware** is separate from nixpkgs (Framework ships BIOS/fingerprint/etc.
updates through LVFS; fwupd is already enabled):

```bash
fwupdmgr refresh && fwupdmgr update
```

**Flatpaks** (if you've installed any) update independently too:

```bash
flatpak update
```

**If an update breaks something:** reboot and pick the previous generation
in the boot menu — that's the whole system exactly as it was. Then
`git checkout flake.lock` in the repo to stay on the old versions until
you feel like retrying.

**Cleanup:** old generations accumulate in the boot menu and on disk. A
weekly garbage collection is already configured (deletes generations older
than 14 days). To free space manually right now:

```bash
sudo nix-collect-garbage --delete-older-than 14d
```

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
