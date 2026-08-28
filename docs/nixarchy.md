# Nixarchy

[Nixarchy](https://github.com/olafkfreund/nixarchy) vendors Omarchy and adapts
its packages, scripts, menus, themes, plugins, and updates for NixOS. This
configuration consumes those modules directly instead of maintaining a local
Omarchy implementation.

The deployed Intel laptop exposes `framework-intel-core-ultra-nixarchy`. This
profile keeps Plasma, SDDM, and the Breeze greeter, then adds **Omarchy** as a
second login session for Jason. The ordinary `framework-intel-core-ultra`
output remains Plasma-only.

## Using the profile

Schedule the profile after a successful Restic snapshot:

```bash
sudo ./scripts/switch-desktop.sh nixarchy --backup
sudo systemctl reboot
```

At SDDM, select **Omarchy** to enter Nixarchy or **Plasma** to use the existing
desktop. Discord, Telegram, browsers, Steam, repositories, and other personal
application data remain available in both sessions. Generic `Hyprland` entries
are not the Nixarchy desktop; use the explicitly named **Omarchy** entry.

The upstream module seeds mutable configuration without overwriting existing
files. Personal changes such as touchpad behavior and window opacity therefore
remain in `~/.config/hypr` across normal flake updates. Nixarchy manages the
Omarchy compatibility layer; this repository only supplies the session,
system integration, and a small shared-home safety guard.

That guard marks Omarchy's Arch-specific first-login orchestration complete
after Nixarchy has seeded its configuration. The skipped script would map the
XDG Desktop folder to `$HOME`, causing Plasma to display every home-directory
entry as a desktop icon, and would try to enable user services that do not
exist in the NixOS port.

Stock application preinstalls and shell aliases are disabled because this
flake already owns packages and shell configuration. Install, Remove, and the
Omarchy system-update menu rows are hidden; themes, plugins, setup actions,
shortcuts, menus, networking, and other desktop behavior remain
upstream-managed.

## Updates and fallback

`flake.lock` pins Nixarchy. It changes only when the flake inputs are updated,
and the repository checks evaluate the complete Nixarchy laptop profile before
the change is applied.

If an Omarchy session is temporarily broken, select **Plasma** in SDDM. No
profile switch is required. To remove Nixarchy from future boots and return to
the Plasma-only output:

```bash
sudo ./scripts/switch-desktop.sh plasma
sudo systemctl reboot
```

NixOS generations roll back system configuration but not mutable home files.
The desktop safety guard and Restic home snapshots cover that separate state.
