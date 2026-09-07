# VM Guests

Each desktop environment gets a fresh VM and a separate home directory. This
avoids one desktop's cursor, font, display, or dconf state affecting another.

Available targets:

```text
qemu-vm       GNOME
vm-cosmic     COSMIC
vm-hyprland   Hyprland
vm-cinnamon   Cinnamon
vm-nixarchy   Nixarchy (Omarchy desktop; experimental)
```

## Create a Guest

1. In virt-manager, create a VM from the NixOS graphical ISO.
2. Select **Customize configuration before install**.
3. Set firmware to **UEFI/OVMF**; the guests use systemd-boot.
4. Use a virtio disk of at least 30 GiB and the default virtio network.
5. Set video to **virtio**, not QXL.
6. Either leave 3D and display OpenGL both disabled, or enable both together.

Known-good accelerated host commands are:

```bash
virt-xml -c qemu:///system VM_NAME --edit \
  --video model=virtio,accel3d=yes
virt-xml -c qemu:///system VM_NAME --edit \
  --graphics gl=yes,rendernode=/dev/dri/by-path/HOST_GPU_RENDER_NODE
```

An OpenGL SPICE display is local-only, which is appropriate when virt-manager
runs on the same laptop. Video changes require a complete VM power-off.

## Install NixOS

Use the graphical installer, then clone this repository and replace the target
guest's `hardware-configuration.nix` with the generated file:

```bash
cp /etc/nixos/hardware-configuration.nix \
  hosts/VM_TARGET/hardware-configuration.nix
sudo nixos-rebuild boot --flake .#VM_TARGET
sudo reboot
```

The direct installer also works after the target filesystem is mounted:

```bash
sudo ./scripts/install-host.sh VM_TARGET
```

## Guest Integration

`modules/nixos/vm-guest.nix` enables the QEMU guest agent and SPICE daemon for
IP reporting, clean shutdown, clipboard sharing, and display resizing.

The desktop package's SPICE XDG autostart entry is masked, and one user systemd
unit owns the session agent. This avoids greeter/session races and duplicate
agents. The unit retries briefly because graphical-session environment
variables may reach the user systemd manager just after login.

VMs share the common base, containers, and Home Manager profile. They do not
inherit laptop-only firmware services, Bluetooth, Tailscale, Flatpak, libvirt,
or virt-manager.

## Retesting the SPICE workaround

Use a disposable guest or snapshot. Record the desktop, Nixpkgs revision, and
GNOME/SPICE versions before testing. In the test guest's `configuration.nix`,
set `jbrake.spiceSessionWorkaround.enable = lib.mkForce false` (add `lib` to the
module arguments). This disables the custom session service and its paired
XDG autostart mask together, while keeping the normal SPICE daemon enabled.
The retained VM profiles explicitly enable this workaround in `mkVmHost`;
the module defaults to disabled for other users.

Rebuild and reboot the guest, then test clipboard sharing in both directions
and window-driven display resizing. Repeat across logout/login, lock/unlock,
and a second reboot. Check `pgrep -a spice-vdagent` and the system/user journals
for missing agents, competing greeter agents, or repeated restarts. If upstream
startup works consistently on the retained guest desktops, retire both custom
pieces together; otherwise restore them and record the failing versions and
steps. This trial has not yet been performed.

## Nixarchy trial

Nixarchy has its own pinned nixpkgs and Home Manager inputs because its desktop
requires packages missing from NixOS 26.05. All other profiles retain their
existing stable inputs. The trial reuses our base, Podman and guest configuration.

Build and launch from this repository (no ISO installation needed):

```bash
nix build .#nixosConfigurations.vm-nixarchy.config.system.build.vm -o result-nixarchy-vm
./result-nixarchy-vm/bin/run-vm-nixarchy-vm
```

The runner uses 8 GiB RAM, four virtual CPUs, and a separate 32 GiB sparse disk
named `vm-nixarchy-trial.qcow2` in the working directory. It logs in as `jason`;
the trial password is `nixarchy`. These login settings apply only to the generated
VM runner. Existing VM images are not reused.

`Super + Space` opens the menu; `Super + K` lists shortcuts. Terminal settings
are seeded by Nixarchy so its theme switching can update them. Rendering uses
software for portability, so animation performance is not representative of
running on the laptop GPU.

This runner is for trying the desktop. The guest does not contain a writable
checkout of this repository; menu-driven system rebuilds require installing the
guest and setting up that checkout first. Rebuild and relaunch the runner to
try configuration changes. Closing the QEMU window stops the trial and keeps
its disk for the next launch.
