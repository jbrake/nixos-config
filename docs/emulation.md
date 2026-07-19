# Emulation

Both physical Framework laptops receive the same emulation host configuration
in `modules/nixos/emulation.nix`. VM guests do not receive it.

## Architecture

```text
NixOS
  ├─ Steam + Steam hardware rules + hidapi
  ├─ Gamescope login session + GameMode
  ├─ uinput and broad game-controller udev rules
  ├─ declaratively managed RetroDECK Flatpak
  │    ├─ ES-DE library interface
  │    ├─ RetroArch and standalone emulators
  │    └─ ~/retrodeck/{roms,bios,saves,...}
  └─ declaratively managed standalone Ryubing Flatpak
       └─ ~/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx
```

RetroDECK is not packaged in Nixpkgs and its only supported Linux distribution
format is Flatpak. `nix-flatpak` declares RetroDECK, standalone Ryubing, and the
Flathub remote in the NixOS flake. The packages are installed system-wide after
activation and updated weekly. Other manually installed Flatpaks are left
alone.

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
flatpak list --app | grep -E 'RetroDECK|Ryujinx'
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

## Nintendo Switch

Switch emulation is deliberately standalone. RetroDECK permanently removed its
Switch components in 2026, so `modules/nixos/emulation.nix` declares the stable
Ryubing Flatpak separately. Flathub labels this an unverified community package
that is not officially supported by the Ryubing project; review updates before
using them if that trust boundary changes.

The AMD Framework was initialized with Ryubing 1.3.3 and the owner-supplied
16.1.0 firmware and keys. The firmware installer verified all 229 NCA files and
reports `Firmware Version: 16.1.0`. Its important private locations are:

| Content | Location |
| --- | --- |
| Product and title keys | `~/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx/system` |
| Installed firmware | `~/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx/bis/system/Contents/registered` |
| Saves, profiles, caches, and configuration | `~/.var/app/io.github.ryubing.Ryujinx/config/Ryujinx` |
| Dumped games | `~/retrodeck/roms/switch` |

The key files must remain mode `0600`. Do not commit keys, firmware, games, or
save data to this repository. Only use files dumped from hardware and games you
own. An `smb://` URL is a file-manager location rather than a filesystem path,
so Ryubing cannot use it as a game directory. Copy games to
`~/retrodeck/roms/switch`, or mount the NAS at a stable path below the home
directory and add that absolute path under **Options -> Settings -> User
Interface -> Game Directories**.

Ryubing is pre-optimized upstream. Keep its shared defaults: Vulkan, Docked
Mode, 1x resolution, 16:9, shader cache, PPTC, filesystem integrity checks, and
backend threading on Auto. The AMD Radeon can usually use 2x or 3x resolution;
the Intel laptop should start at 1x and increase it per game only when frame
pacing remains stable. Avoid global mods, widescreen patches, or resolution
changes because compatibility varies by game.

On a fresh Steam profile, add one non-Steam shortcut before using the NixOS
desktop icon:

1. Add `flatpak` as a non-Steam game and name it exactly **Ryubing**.
2. Set **Launch Options** to `run io.github.ryubing.Ryujinx` and leave the
   executable exactly `"flatpak"`.
3. Restart Steam. Those exact values produce the deterministic game ID used by
   the NixOS launcher.
4. Start Ryubing from Steam with the Puck powered on. Hold Start/Menu until
   Steam reports **Changed from Desktop to Gamepad** if necessary.
5. In **Options -> Settings -> Input**, keep Docked Mode enabled, configure
   Player 1 as a Pro Controller, choose Steam's virtual gamepad, load its
   default mapping, and save. The device is only present while the physical
   controller is powered on and Steam Input is in Gamepad mode.

On the Intel Framework, the NixOS rebuild installs the same application and
launcher. Restore the Ryubing application-data directory from Restic (or
repeat the owner-dumped key and firmware installation) and add the same Steam
shortcut if that Steam profile was not restored.

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

The live RetroArch, PCSX2, and Dolphin configurations include native controller
chords in addition to RetroDECK's existing keyboard hotkeys. They therefore work
when Triton is exposing its virtual Xbox gamepad even without a Triton-specific
RetroDECK Steam Input template. `Select` below is the Xbox-style View/Back
button.

Hold `Select` while pressing:

| Combination | Action | Native support |
| --- | --- | --- |
| `Select + A` | Pause or resume | RetroArch, PCSX2, Dolphin |
| `Select + B` | Take a screenshot | RetroArch, PCSX2, Dolphin |
| `Select + X` | Toggle fullscreen | RetroArch, PCSX2, Dolphin |
| `Select + Y` | Open the Quick/Pause Menu | RetroArch, PCSX2 |
| `Select + L1` | Load the selected state | RetroArch, PCSX2, Dolphin |
| `Select + R1` | Save to the selected state | RetroArch, PCSX2, Dolphin |
| `Select + L2` | Rewind while held | RetroArch, when rewind is enabled |
| `Select + R2` | Fast-forward while held | RetroArch, PCSX2 |
| `Select + D-pad Left/Right` | Previous or next state slot | RetroArch, PCSX2, Dolphin |
| `Select + Start` | Quit the current emulator | RetroArch, PCSX2, Dolphin |
| `L3 + R3` | Open the Quick Menu without `Select` | RetroArch |

Reset is intentionally not bound directly because it is too easy to trigger by
accident. In RetroArch, use `Select + Y`, then **Quick Menu -> Restart/Reset**.
PCSX2 exposes reset from its `Select + Y` pause menu. Dolphin has no equivalent
controller overlay; exit and relaunch the game when a full reset is needed.

Rewind remains disabled globally to avoid its CPU and memory cost on N64 and
PS1. It can be enabled in a core or game override; `Select + L2` then works.
Save states are a convenience and may become incompatible after emulator/core
updates, so ordinary in-game saves remain the durable default.

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
| Switch firmware, keys, saves, and configuration | `~/.var/app/io.github.ryubing.Ryujinx` |

On Framework hosts with the Restic job enabled, the home backup keeps BIOS,
saves, save states, screenshots, mutable component configuration, and the
entire Ryubing application-data tree. This includes its private keys, installed
firmware, and Switch saves. It skips `~/retrodeck/roms` because the canonical
ROM library is already stored on the NAS. Restore or remount that library
separately after reinstalling.

The configuration installs RetroDECK on both laptops, but it does not
automatically copy ROMs or saves between them. Do not run the same mutable save
tree concurrently from a network share. Use RetroDECK's supported sync feature
or a deliberate one-way/snapshot-backed synchronization workflow if shared
saves are needed later.
