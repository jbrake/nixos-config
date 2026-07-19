# RetroDECK Emulation

Both physical Framework laptops receive the same emulation host configuration
in `modules/nixos/emulation.nix`. VM guests do not receive it.

## Architecture

```text
NixOS
  ├─ Steam + Steam hardware rules + hidapi
  ├─ Gamescope login session + GameMode
  ├─ uinput and broad game-controller udev rules
  └─ declaratively managed RetroDECK Flatpak
       ├─ ES-DE library interface
       ├─ RetroArch and standalone emulators
       └─ ~/retrodeck/{roms,bios,saves,...}
```

RetroDECK is not packaged in Nixpkgs and its only supported Linux distribution
format is Flatpak. `nix-flatpak` declares the application and Flathub remote in
the NixOS flake. The package is installed system-wide after activation and is
updated weekly. Other manually installed Flatpaks are left alone.

RetroDECK deliberately owns the emulator configuration below
`~/.var/app/net.retrodeck.retrodeck`. Its release migrations keep coordinated
versions of ES-DE, emulators, hotkeys, shaders, and presets working together.
Do not replace those generated files with Home Manager links: they are mutable
application state, and making them read-only breaks RetroDECK resets and
upgrades.

## Apply and Verify

From the repository:

```bash
./scripts/rebuild.sh
systemctl status flatpak-managed-install.service
flatpak list --app | grep RetroDECK
```

The first activation needs network access while the service downloads the
Flatpak and its runtime. A temporary Flathub outage does not invalidate the
NixOS generation; the service retries after 60 seconds. Inspect failures with:

```bash
journalctl -u flatpak-managed-install.service -b
```

## First Run

In `Steam -> Settings -> Controller`, leave Steam Input enabled for the Steam
Controller and enable the Xbox, PlayStation, Switch Pro, and generic-controller
compatibility toggles. This lets future guest controllers use the same library.

Before the first setup only, launch RetroDECK directly from a terminal with:

```bash
flatpak run net.retrodeck.retrodeck
```

Choose these options when prompted:

1. Use **Home Directory** storage (called **Internal** in older releases). This
   creates `~/retrodeck` on the fast internal NVMe and keeps paths identical on
   both laptops.
2. Choose **Yes** when asked to add RetroDECK to Steam.
3. Leave **Install Steam Controller layouts** enabled.
4. Initially leave favorite-game Steam synchronization disabled. RetroDECK
   itself is the one Steam shortcut; favorite games can be exported later.
5. Only download firmware RetroDECK identifies as freely redistributable. Dump
   proprietary BIOS, firmware, keys, and games from hardware and media you own.
6. Exit RetroDECK and fully restart Steam after setup so the shortcut and input
   templates are discovered. After that first run, use the normal RetroDECK
   application icon; the NixOS desktop entry routes it through Steam Input.

Add games under the system folders RetroDECK creates in `~/retrodeck/roms` and
required firmware under `~/retrodeck/bios`. ES-DE hides empty systems, so the
library stays uncluttered.

## Normal Use

There are two supported ways to play, and both launch RetroDECK through Steam:

- From a normal desktop, use the **RetroDECK** application icon. The shared
  NixOS configuration opens its deterministic non-Steam shortcut in Steam. It
  is equivalent to opening Steam and choosing the RetroDECK library entry.
- At the display-manager login screen, select the **Steam** session. NixOS then
  starts Steam's controller-first interface inside Gamescope. Launch RetroDECK
  from `Library -> Non-Steam`. Log out through Steam to return to the login
  screen.

Launching through Steam is required for the stock 2026 Steam Controller Puck.
Without Steam Input, the Puck exposes fallback mouse and keyboard interfaces,
so ES-DE may appear partly usable while emulator controls are incorrect. Steam
Input remains active while ES-DE starts and waits for each emulator.

Prefer the supplied wireless puck over Bluetooth when docked. Bluetooth is
useful for travel, while Valve recommends the puck as the fastest and most
reliable connection. Use USB-C when applying controller firmware updates.
Steam must remain open for advanced trackpad, gyro, grip, and per-application
mappings.

## Controller Defaults and Hotkeys

Steam identifies Valve's 2026 controller internally as **Triton**. On a Linux
desktop its standard Steam Input desktop layout contains two action sets:
**Desktop** (mouse and keyboard) and **Gamepad** (a virtual Xbox pad). Steam can
return to Desktop when RetroDECK hands focus to a child emulator window.

If an emulator receives mouse, keyboard, or incorrect button input, **hold the
Start/Menu button** until Steam displays `Changed from Desktop to Gamepad`.
Hold it again to return to desktop controls. The selection may reset when the
controller reconnects or Steam restarts, so this is the first troubleshooting
step. It is runtime Steam state rather than a NixOS setting; the declarative
launcher ensures Steam Input is present but should not replace Steam's mutable
desktop layout.

The layout outputs a conventional virtual Xbox gamepad to every emulator. The
RetroArch, PCSX2, and Dolphin configurations then use the same positional
mapping: the bottom, right, left, and top face buttons retain their physical
roles across controllers. Consequently, SNES labels intentionally differ from
the Xbox-style labels printed on the Steam Controller: physical `A/B/X/Y`
correspond to SNES `B/A/Y/X`. This is the standard positional mapping and keeps
platforming controls in their original locations.

Hold the controller's `Select` button while pressing:

| Combination | Action |
| --- | --- |
| `Select + Start` | Quit the current emulator |
| `Select + A` | Pause or resume |
| `Select + X` | Toggle fullscreen |
| `Select + Y` | Open the emulator menu |
| `Select + L1` | Load state |
| `Select + R1` | Save state |
| `Select + L2` | Rewind where supported |
| `Select + R2` | Fast-forward |
| `Select + D-pad Left/Right` | Previous or next state slot |

The older Gordon layout is for a different controller type and should not be
selected for Triton.

## Display, Scaling, and Filters

The shared defaults are intentionally conservative because both Framework GPUs
and any external monitor must work:

- Keep ES-DE at the display's native resolution and refresh rate.
- Keep each system's original aspect ratio. Do not enable global stretch or a
  global widescreen hack; use a tested per-game patch instead.
- Keep RetroDECK's per-system shader and renderer defaults. They choose Vulkan
  where it is mature and preserve the appropriate pixel or 3D scaling path.
- For 2D consoles, use integer scaling and no smoothing for crisp pixels. If a
  less sharp image is desired, enable a lightweight CRT or LCD shader for that
  system rather than a global filter.
- For PS1, N64, Dreamcast, PSP, PS2, GameCube, and Wii, start at 2x internal
  resolution on the Intel laptop. The Radeon 890M can usually move to 3x or 4x.
- For Wii U, PS3, and other demanding emulators, start at 1280x720 or 1920x1080
  and increase resolution per game only after frame pacing is stable.
- Leave frame skipping, run-ahead, rewind, widescreen hacks, and texture packs
  off globally. Enable them per system or game because each has compatibility,
  latency, memory, or storage costs.

Useful global presets live in **RetroDECK Configurator -> Settings**. Quick
Resume is convenient but save states are not a substitute for in-game saves.
RetroAchievements is safe to enable after signing in; Hardcore Mode disables
rewind, cheats, and save states by design.

## Data and Backups

Important locations are:

| Content | Location |
| --- | --- |
| Games | `~/retrodeck/roms` |
| BIOS and firmware | `~/retrodeck/bios` |
| In-game saves | `~/retrodeck/saves` |
| Save states | `~/retrodeck/states` |
| Screenshots | `~/retrodeck/screenshots` |
| Mutable component configuration | `~/.var/app/net.retrodeck.retrodeck` |

On Framework hosts with the Restic job enabled, these locations are included in
the existing home backup. A large ROM library will therefore consume NAS space;
add `~/retrodeck/roms` to the Restic exclusion list only if the original dumps
are safely archived somewhere else.

The configuration installs RetroDECK on both laptops, but it does not
automatically copy ROMs or saves between them. Do not run the same mutable save
tree concurrently from a network share. Use RetroDECK's supported sync feature
or a deliberate one-way/snapshot-backed synchronization workflow if shared
saves are needed later.
