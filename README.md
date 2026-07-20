# Jason's NixOS Configurations

[![CI](https://github.com/jbrake/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/jbrake/nixos-config/actions/workflows/ci.yml)

Personal, multi-host NixOS configurations for Framework laptops and disposable
desktop-environment VMs. The repository uses flakes, Home Manager, small
role-based modules, and CI to keep the deployed configuration reproducible.

> [!IMPORTANT]
> This is a live personal configuration, not a general-purpose NixOS installer.
> It contains Jason's username, hostnames, hardware assumptions, backup endpoint,
> application choices, and machine-specific state. Treat it as a reference or
> fork it and adapt those values before deploying it. Review every command before
> running it as root.

## Highlights

- Plasma, GNOME, Cinnamon, COSMIC, and Hyprland profiles share one laptop
  configuration without sharing desktop-sensitive state.
- Boot-time state capsules preserve each desktop's settings while personal files
  and application profiles remain common.
- Role-based modules separate laptop hardware, virtual-machine guests,
  applications, containers, backups, emulation, and desktop behavior.
- Rebuild and update scripts retain the active desktop profile, verify changes,
  and avoid switching to an unbuildable update.
- Encrypted Restic backups provide home-directory history and fresh-install
  recovery independently of the local desktop capsules.
- CI formats and lints the repository, checks documentation links, scans the full
  Git history for secrets, evaluates every host, and builds all AMD profiles.

## Supported Profiles

The unsuffixed laptop output uses Plasma. The other desktops append their name
to the hardware output, such as `framework-amd-ai-300-gnome`.

| Hardware | Base output | Status |
| --- | --- | --- |
| Framework 13, AMD Ryzen AI 9 HX 370 | `framework-amd-ai-300` | Deployed; being replaced |
| Framework 13 Pro, Intel Core Ultra Series 3 | `framework-intel-core-ultra` | Planned; hardware placeholder only |

| Desktop | Output suffix |
| --- | --- |
| Plasma | none |
| GNOME | `-gnome` |
| Cinnamon | `-cinnamon` |
| COSMIC | `-cosmic` |
| Hyprland with Caelestia | `-hyprland` |

Disposable VM profiles remain independent:

| Output | Role | Status |
| --- | --- | --- |
| `qemu-vm` | GNOME guest under virt-manager | Available |
| `vm-cosmic` | COSMIC guest | Available |
| `vm-hyprland` | Hyprland guest | Available |
| `vm-cinnamon` | Cinnamon guest | Available |

## Architecture

- `flake.lock` pins Nixpkgs, Home Manager, Plasma Manager, Caelestia, hardware
  profiles, and the two AI CLI package sources.
- Physical laptops add laptop, virtualization-host, workstation, emulation,
  backup, fingerprint, and desktop-state roles.
- Guests omit laptop firmware, Bluetooth, VPN, backups, emulation, and nested
  libvirt services.
- Each VM has one desktop environment to prevent one desktop's cursor, font, or
  settings from contaminating another.
- Home Manager owns user tools and selected desktop settings. Machine-specific
  Plasma panel IDs are restricted to the deployed AMD host.
- The hardware profiles define encrypted Restic backups to Jason's Synology NAS.

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
modules/nixos/desktop-state.nix        five-way desktop state activation
modules/nixos/containers.nix           Podman and Distrobox tooling
modules/nixos/backup.nix               encrypted Restic backups
modules/nixos/fingerprint.nix          Framework fingerprint behavior
home/jason/home.nix                    Home Manager profile
scripts/                               install, rebuild, update, and checks
docs/                                  recovery and hardware-specific guides
```

## Adapting This Repository

Fork the repository before making it your system configuration, then clone your
fork rather than this upstream repository:

```bash
git clone https://github.com/YOUR_USERNAME/nixos-config.git
cd nixos-config
```

At minimum, review and replace the following:

1. Change the default username, Git identity, home module, UID, and hardcoded
   script paths in `flake.nix`, `modules/nixos/base.nix`, `home/`, and `scripts/`.
2. Define a host for your exact hardware. Generate your own
   `hardware-configuration.nix`; never reuse another machine's filesystem UUIDs.
3. Disable `enableBackup` for your profiles until `modules/nixos/backup.nix`, the
   NAS host key, repository path, account, and root-only secrets refer to your
   own backup destination.
4. Review the desktop, application, Tailscale, fingerprint, virtualization, and
   emulation modules and remove roles you do not want.
5. Choose partitioning and encryption for your own threat model. The owner's
   current disk layout below is descriptive, not a recommendation.
6. Keep `system.stateVersion` at the original value on an existing installation;
   choose the appropriate value deliberately for a genuinely new configuration.

This search identifies the main owner-specific values, but it is not a substitute
for reading the configuration:

```bash
rg -ni 'jason|jbrake|pnut001|brake-nas|10\.69\.1\.164|restic-jason' .
```

Before deploying a fork, run the validation commands below and inspect the full
result of `nix flake show`.

## Owner Installation

The procedures in this section are Jason's reinstall runbook. They intentionally
assume user `jason`, this repository layout, one of the listed Framework models,
and the configured Synology backup environment.

### Graphical installer

> [!CAUTION]
> Selecting **Erase disk** destroys the existing contents of the selected drive.
> The no-encryption layout documented here is the owner's current choice, not a
> requirement of this flake or a recommendation for other systems.

1. Boot the NixOS Plasma ISO and use the graphical installer.
2. The current owner procedure selects erase disk, no disk encryption, no disk
   swap, and user `jason`. The configuration enables compressed zram swap.
3. After the installer reboots, open a terminal and run the following. This
   example targets the planned Intel laptop; use `framework-amd-ai-300` for both
   variables on the AMD laptop. Append `-gnome`, `-cinnamon`, `-cosmic`, or
   `-hyprland` to `profile` to start with another desktop.

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

For an owner installation that has already been manually partitioned and
mounted at `/mnt`:

```bash
git clone https://github.com/jbrake/nixos-config.git
cd nixos-config
sudo ./scripts/install-host.sh framework-intel-core-ultra
```

The script generates the hardware configuration, installs the flake, prompts
for the real `jason` password, and clones only Git-managed repository content
to `/home/jason/Documents/repos/nixos-config` on the target system. It is not a
generic installer and refuses to overwrite an existing target checkout.

The Intel configurations remain evaluation-safe for CI, but install, rebuild,
and update scripts refuse to deploy them while the hardware file contains the
`INTEL_HARDWARE_PLACEHOLDER` marker. Generating the real hardware configuration
removes that guard.

## Owner First Boot

Point the checkout at Jason's writable SSH remote:

```bash
cd ~/Documents/repos/nixos-config
git remote set-url origin git@github.com:jbrake/nixos-config.git
```

Anyone using a fork must substitute their own repository URL.

### GitHub CLI authentication

`github-cli` is installed in the shared base profile. Home Manager owns
`~/.config/git/config`, so GitHub CLI cannot update that read-only generated
file during its normal login flow. Authenticate with a separate, writable
global Git config instead:

```bash
GIT_CONFIG_GLOBAL="$HOME/.gitconfig" gh auth login -h github.com --web
```

Confirm the login with `gh auth status`. Repository traffic endpoints require
administrative access to the repository being queried.

Enroll the fingerprint reader and connect Tailscale:

```bash
fprintd-enroll jason
sudo tailscale up
```

Application accounts, phone pairing, and display scale remain interactive.
Home Manager declares shared defaults and desktop-specific file managers. See
the desktop-switching guide for desktop defaults, shortcuts, and state isolation.

## Daily Operations

Apply the active host and desktop configuration:

```bash
./scripts/rebuild.sh
```

Switch desktops while preserving separate state for each one:

```bash
sudo ./scripts/switch-desktop.sh gnome
sudo ./scripts/switch-desktop.sh cinnamon
sudo ./scripts/switch-desktop.sh cosmic
sudo ./scripts/switch-desktop.sh hyprland
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

Evaluate every host and build all five AMD desktop configurations:

```bash
nix flake check --print-build-logs
```

`scripts/rebuild.sh` also prints the closure difference between the previous
and new system generations.

## Guides

- [Backup and full recovery](docs/backup-recovery.md)
- [Switching desktop environments](docs/desktop-switching.md)
- [VM guest setup](docs/vm-guests.md)
- [Fingerprint behavior](docs/fingerprint.md)
- [Hardware notes](docs/hardware.md)
- [RetroDECK emulation and Steam Controller](docs/emulation.md)

## Public Repository Safety

The repository intentionally publishes hostnames, hardware details, filesystem
UUIDs, package choices, a private-LAN NAS address, and a public SSH host key.
Those values cannot authenticate to the NAS or decrypt the Restic repository.

Never commit private SSH keys, authentication tokens, browser profiles, VPN
credentials, application state, or files under `/var/lib/secrets`. CI scans both
the current tree and full Git history with Gitleaks.

## License

Released under the [MIT License](LICENSE).
