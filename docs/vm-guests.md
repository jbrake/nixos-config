# VM Guests

Each desktop environment gets a fresh VM and a separate home directory. This
avoids one desktop's cursor, font, display, or dconf state affecting another.

Available targets:

```text
qemu-vm       GNOME
vm-cosmic     COSMIC
vm-hyprland   Hyprland
vm-cinnamon   Cinnamon
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
