{
  pkgs,
  username,
  ...
}:

# Shared by every desktop profile on both physical Framework laptops. RetroDECK
# owns its emulator configs and migrates them with each release; NixOS owns the
# host facilities and converges the Flatpak installation to the declared app.
let
  # Steam derives this stable non-Steam game ID from the shortcut name
  # "RetroDECK" and executable "flatpak". RetroDECK's Steam Tools installs the
  # matching shortcut and its controller templates during first-run setup.
  retrodeckSteamGameId = "10745277884156346368";

  # Steam derives this ID from shortcut name "Ryubing" and executable
  # "flatpak". Unlike RetroDECK, Ryubing's one-time shortcut is added manually
  # because Steam owns a mutable binary shortcuts.vdf in the user's home.
  ryubingSteamGameId = "13571547157277704192";

  # The 2026 Steam Controller's stock Puck relies on Steam Input for ordinary
  # gamepad emulation. Shadow the Flatpak-exported desktop entry so launching
  # RetroDECK from an application menu cannot accidentally use Puck lizard mode
  # (mouse/keyboard) instead of the configured virtual Xbox gamepad.
  retrodeckSteamLauncher = pkgs.makeDesktopItem {
    name = "net.retrodeck.retrodeck";
    desktopName = "RetroDECK";
    genericName = "Emulation Frontend";
    comment = "Launch RetroDECK through Steam Input";
    exec = "${pkgs.steam}/bin/steam steam://rungameid/${retrodeckSteamGameId}";
    icon = "net.retrodeck.retrodeck";
    categories = [
      "Game"
      "Emulator"
    ];
    terminal = false;
  };

  # Shadow the Flatpak export for the same reason as RetroDECK: the standalone
  # Switch emulator should receive Triton's Steam Input virtual gamepad.
  ryubingSteamLauncher = pkgs.makeDesktopItem {
    name = "io.github.ryubing.Ryujinx";
    desktopName = "Ryubing";
    genericName = "Nintendo Switch Emulator";
    comment = "Launch Ryubing through Steam Input";
    exec = "${pkgs.steam}/bin/steam steam://rungameid/${ryubingSteamGameId}";
    icon = "io.github.ryubing.Ryujinx";
    categories = [
      "Game"
      "Emulator"
    ];
    terminal = false;
  };

in
{
  services.flatpak = {
    enable = true;
    packages = [
      {
        appId = "net.retrodeck.retrodeck";
        origin = "flathub";
      }
      # RetroDECK permanently removed Switch emulation in 0.10.5b. Keep the
      # community Ryubing build standalone so RetroDECK updates cannot remove
      # its emulator, firmware, keys, saves, or configuration.
      {
        appId = "io.github.ryubing.Ryujinx";
        origin = "flathub";
      }
    ];

    # Flatpak applications are not Nix-store artifacts. Update them on a quiet,
    # predictable cadence instead of making every rebuild depend on Flathub.
    update = {
      onActivation = false;
      auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };

    # Preserve unrelated Flatpaks installed interactively.
    uninstallUnmanaged = false;
    uninstallUnused = false;
  };

  programs.steam = {
    # The 2026 Steam Controller needs hidapi in Steam's FHS environment for
    # firmware and full HID communication. extest lets Steam Input synthesize
    # mouse/keyboard events reliably in Wayland desktop sessions.
    extraPackages = [ pkgs.hidapi ];
    extest.enable = true;

    # Adds a controller-first "Steam" login session without replacing any of
    # the normal Plasma/GNOME/Cinnamon/COSMIC/Hyprland sessions.
    gamescopeSession.enable = true;
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode.enable = true;

  # Steam already installs Valve's current rules. The community rules extend
  # access to common adapters, arcade sticks, dance pads, and other controllers
  # RetroDECK may use later.
  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  hardware.uinput.enable = true;
  users.users.${username}.extraGroups = [
    "gamemode"
    "uinput"
  ];

  environment.systemPackages = [
    retrodeckSteamLauncher
    ryubingSteamLauncher
  ];
}
