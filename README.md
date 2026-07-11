# NixOS Configurations

[![CI](https://github.com/jbrake/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/jbrake/nixos-config/actions/workflows/ci.yml)

Personal, multi-host NixOS configurations for Framework laptops and disposable
desktop-environment VMs. The repository uses flakes, Home Manager, small
role-based modules, and CI to keep the deployed configuration reproducible.

## Hosts and Profiles

Each Framework exposes the same four desktop profiles. The unsuffixed output
is Plasma.

| Hardware | Plasma | GNOME | Cinnamon | COSMIC | Status |
| --- | --- | --- | --- | --- | --- |
| AMD Ryzen AI 9 HX 370 | `framework-amd-ai-300` | `framework-amd-ai-300-gnome` | `framework-amd-ai-300-cinnamon` | `framework-amd-ai-300-cosmic` | Deployed; being replaced |
| Intel Core Ultra Series 3 | `framework-intel-core-ultra` | `framework-intel-core-ultra-gnome` | `framework-intel-core-ultra-cinnamon` | `framework-intel-core-ultra-cosmic` | Planned; guarded hardware placeholder |

Disposable VM profiles remain independent:

| Host | Role | Status |
| --- | --- | --- |
| `qemu-vm` | GNOME guest under virt-manager | Available |
| `vm-cosmic` | COSMIC guest | Available |
| `vm-hyprland` | Hyprland guest | Available |
| `vm-cinnamon` | Cinnamon guest | Available |

## Design

- `flake.lock` pins Nixpkgs, Home Manager, Plasma Manager, hardware profiles,
  and the two AI CLI package sources.
- `base.nix` contains settings shared by every host.
- Physical laptops add laptop and virtualization-host roles; guests do not
  inherit laptop firmware, Bluetooth, VPN, or nested libvirt services.
- All four laptop desktops share one workstation application module; their
  desktop settings are swapped through separate, Restic-backed state capsules.
- Each VM has one desktop environment to avoid cross-desktop state in `$HOME`.
- Home Manager owns user tools and selected desktop settings. Machine-specific
  Plasma panel IDs are restricted to the deployed AMD host.
- Restic backs up unmanaged home data to an encrypted Synology repository.

## Layout

```text
flake.nix                              host constructors, outputs, checks
flake.lock                             pinned input revisions
hosts/<host>/configuration.nix         machine-specific settings
hosts/<host>/hardware-configuration.nix generated or guarded placeholder
modules/nixos/base.nix                 settings shared by every host
modules/nixos/laptop.nix               physical-laptop services
modules/nixos/virtualization-host.nix  libvirt and virt-manager host services
modules/nixos/workstation-apps.nix     GUI applications shared by laptop desktops
modules/nixos/desktop-*.nix            reusable laptop and VM desktop roles
modules/nixos/desktop-state.nix        four-way desktop state activation
modules/nixos/containers.nix           Podman and Distrobox tooling
modules/nixos/backup.nix               encrypted Restic backups
modules/nixos/fingerprint.nix          Framework fingerprint behavior
home/jason/home.nix                    Home Manager profile
scripts/                               install, rebuild, update, and checks
docs/                                  recovery and hardware-specific notes
```

## Install a Framework Laptop

### Graphical installer

1. Boot the NixOS Plasma ISO and use the graphical installer.
2. Current partitioning choices are erase disk, no disk encryption, no disk
   swap, and user `jason`. The configuration enables compressed zram swap.
3. After the installer reboots, open a terminal and run the following. This
   example targets the incoming Intel laptop; use `framework-amd-ai-300` for
   both variables on the AMD laptop. Append `-gnome`, `-cinnamon`, or `-cosmic`
   to `profile` to start with another desktop.

   ```bash
   mkdir -p ~/Documents/repos
   cd ~/Documents/repos
   nix-shell -p git
   git clone https://github.com/jbrake/nixos-config.git
   cd nixos-config
   hardware=framework-intel-core-ultra
   profile=framework-intel-core-ultra
   cp /etc/nixos/hardware-configuration.nix \
     "hosts/$hardware/hardware-configuration.nix"
   sudo NIX_CONFIG="experimental-features = nix-command flakes" \
     nixos-rebuild boot --flake ".#$profile"
   sudo reboot
   ```

The generated hardware file is required because filesystem identifiers change
on a new installation.

### Direct installer flow

For a manually partitioned system already mounted at `/mnt`:

```bash
git clone https://github.com/jbrake/nixos-config.git
cd nixos-config
sudo ./scripts/install-host.sh framework-intel-core-ultra
```

The script generates the hardware configuration, installs the flake, prompts
for the real `jason` password, and clones only Git-managed repository content
to `/home/jason/Documents/repos/nixos-config` on the target system.

The Intel configurations stay evaluation-safe for CI, but install, rebuild,
and update scripts refuse to deploy them while the hardware file contains the
`INTEL_HARDWARE_PLACEHOLDER` marker. Generating the real hardware configuration
removes that guard.

## First Boot

Set the writable Git remote:

```bash
cd ~/Documents/repos/nixos-config
git remote set-url origin git@github.com:jbrake/nixos-config.git
```

Enroll the fingerprint reader and connect Tailscale:

```bash
fprintd-enroll jason
sudo tailscale up
```

Application accounts, phone pairing, and display scale remain interactive.
Home Manager declares shared defaults and desktop-specific file managers. See
the desktop-switching guide for GNOME defaults, Cinnamon touchpad behavior,
COSMIC's evolving settings, and state isolation.

## Daily Use

Apply the current host configuration:

```bash
./scripts/rebuild.sh
```

Switch desktops while preserving separate state for each one:

```bash
sudo ./scripts/switch-desktop.sh gnome
sudo ./scripts/switch-desktop.sh cinnamon
sudo ./scripts/switch-desktop.sh cosmic
```

Use the same command with `plasma` to return. Personal files and application
profiles stay shared; desktop-sensitive state is saved automatically in a local
capsule. Add `--backup` only when a fresh encrypted Restic snapshot on the NAS
is also wanted. Normal rebuild and update commands retain the active profile.

Update inputs, prove the new system builds, and switch only after success:

```bash
./scripts/update-system.sh
```

The update script restores the exact previous `flake.lock` if updating or
building fails.

Run a backup now or inspect snapshots:

```bash
sudo systemctl start restic-backups-jason-home.service
sudo restic-jason-home snapshots
```

See [Restic Backup and Recovery](docs/backup-recovery.md) for coverage, NAS key
bootstrap, manual backups, and complete fresh-system recovery.

## Validation

Run the same lint, formatting, link, and secret checks used by CI:

```bash
nix develop --command ./scripts/check.sh
```

Evaluate every host and build all four AMD desktop configurations:

```bash
nix flake check --print-build-logs
```

`scripts/rebuild.sh` also prints the closure difference between the previous
and new system generations.

## Additional Documentation

- [Backup and full recovery](docs/backup-recovery.md)
- [Switching desktop environments](docs/desktop-switching.md)
- [VM guest setup](docs/vm-guests.md)
- [Fingerprint behavior](docs/fingerprint.md)
- [Hardware notes](docs/hardware.md)

## Public Repository Safety

The repository intentionally publishes hostnames, hardware details, filesystem
UUIDs, package choices, a private-LAN NAS address, and public SSH host keys.
Those values cannot authenticate to the NAS or decrypt the Restic repository.

Never commit private SSH keys, authentication tokens, browser profiles, VPN
credentials, application state, or files under `/var/lib/secrets`. CI scans the
full Git history with Gitleaks.

## License

Released under the [MIT License](LICENSE).
