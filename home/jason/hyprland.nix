{
  config,
  lib,
  pkgs,
  ...
}:

let
  shortcutHelp = pkgs.writeShellApplication {
    name = "hyprland-shortcuts";
    runtimeInputs = [ pkgs.zenity ];
    text = ''
            exec zenity --text-info \
              --title="Hyprland shortcuts" \
              --width=720 \
              --height=690 \
              --font="JetBrains Mono 11" <<'EOF'
      GETTING AROUND
        Super or Super+Space       Open apps, settings, and wallpapers
        Super+/                    Show this shortcut guide
        Ctrl+Alt+Delete            Session and power menu
        Super+L                    Lock the laptop

      APPS
        Super+Enter or Super+T     Ghostty terminal
        Super+B                    Brave browser
        Super+E                    Files
        Super+V                    Clipboard history
        Super+.                    Emoji picker

      WINDOWS
        Super+Q                    Close the focused window
        Super+F                    Maximize or restore
        Super+Shift+F              True fullscreen
        Super+Shift+Space          Toggle floating
        Super+Tab                  Cycle through windows
        Super+Arrow                Move focus
        Super+Shift+Arrow          Move a window
        Super+Alt+Arrow            Resize a window
        Super+left mouse drag      Move a window with the mouse
        Super+right mouse drag     Resize a window with the mouse

      WORKSPACES
        Super+1 through 9          Open workspace
        Super+Shift+1 through 9    Move window to workspace
        Three-finger swipe         Move between workspaces

      SCREENSHOTS
        Print                      Select an area and capture it

      TIP
        Start with Super or Super+Space. The launcher can open apps,
        change wallpapers and color schemes, and open Caelestia settings.
      EOF
    '';
  };

  lockHyprland = pkgs.writeShellApplication {
    name = "lock-hyprland";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.hyprlock
      pkgs.systemd
    ];
    text = ''
      if systemctl --user is-active --quiet caelestia.service \
        && hyprctl dispatch global caelestia:lock >/dev/null; then
        exit 0
      fi
      exec hyprlock
    '';
  };

  caelestia = lib.getExe config.programs.caelestia.cli.package;
  themeInit = pkgs.writeShellApplication {
    name = "caelestia-theme-init";
    runtimeInputs = [
      config.programs.caelestia.cli.package
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = ''
      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      scheme="$state_home/caelestia/scheme.json"
      if [[ -e "$scheme" ]]; then
        exit 0
      fi

      sleep 1
      ${caelestia} wallpaper -f "$HOME/Pictures/Wallpapers/NixOS-Moonscape.png"
      ${caelestia} scheme set -n dynamic
      notify-send --app-name="Hyprland" \
        "Welcome to Hyprland" \
        "Press Super or Super+Space for the launcher. Press Super+/ for shortcuts."
    '';
  };
in
{
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
    # UWSM, enabled by the NixOS module, owns the graphical systemd session.
    systemd.enable = false;
    extraLuaFiles."jason-config" = ./hyprland/config.lua;
  };

  programs.caelestia = {
    enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
    settings = {
      appearance.transparency = {
        enabled = true;
        base = 0.82;
        layers = 0.38;
      };
      general = {
        apps = {
          terminal = [ "ghostty" ];
          audio = [ "pavucontrol" ];
          explorer = [ "nautilus" ];
        };
        # The fail-safe hypridle service below owns locking and suspend.
        idle.timeouts = [ ];
      };
      bar = {
        persistent = true;
        showOnHover = false;
        workspaces.shown = 5;
        status.showBattery = true;
      };
      launcher = {
        maxShown = 8;
        enableDangerousActions = false;
        vimKeybinds = false;
      };
      lock = {
        enabled = true;
        enableFprint = false;
        enableHowdy = false;
      };
      services = {
        useFahrenheit = true;
        useTwelveHourClock = false;
        smartScheme = true;
      };
      paths.wallpaperDir = "~/Pictures/Wallpapers";
    };
    cli = {
      enable = true;
      settings.theme = {
        enableTerm = true;
        enableHypr = true;
        enableFuzzel = true;
        enableBtop = true;
        enableGtk = true;
        enableDiscord = false;
        enableSpicetify = false;
        enablePandora = false;
        enableNvtop = false;
        enableHtop = false;
        enableQt = false;
        enableWarp = false;
        enableChromium = false;
        enableZed = false;
        enableCava = false;
        postHook = "${pkgs.hyprland}/bin/hyprctl reload config-only";
      };
    };
  };

  services.hyprpolkitagent.enable = true;
  services.gnome-keyring.enable = true;

  home.packages = [
    lockHyprland
    shortcutHelp
  ];

  home.file = {
    "Pictures/Wallpapers/NixOS-Moonscape.png".source =
      pkgs.nixos-artwork.wallpapers.moonscape.gnomeFilePath;
    "Pictures/Wallpapers/NixOS-Catppuccin-Mocha.png".source =
      pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha.gnomeFilePath;
    "Pictures/Wallpapers/NixOS-Gradient-Grey.png".source =
      pkgs.nixos-artwork.wallpapers.gradient-grey.gnomeFilePath;
  };

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      lock_cmd = ${lib.getExe lockHyprland}
      before_sleep_cmd = ${lib.getExe lockHyprland}
      after_sleep_cmd = ${pkgs.hyprland}/bin/hyprctl dispatch dpms on
      ignore_dbus_inhibit = false
    }

    listener {
      timeout = 300
      on-timeout = ${lib.getExe lockHyprland}
    }

    listener {
      timeout = 600
      on-timeout = ${pkgs.hyprland}/bin/hyprctl dispatch dpms off
      on-resume = ${pkgs.hyprland}/bin/hyprctl dispatch dpms on
    }

    listener {
      timeout = 1200
      on-timeout = ${pkgs.systemd}/bin/systemctl suspend
    }
  '';

  systemd.user.services = {
    caelestia-theme-init = {
      Unit = {
        Description = "Initialize the Caelestia wallpaper and dynamic color scheme";
        After = [ "caelestia.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe themeInit;
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    cliphist-text = {
      Unit = {
        Description = "Store text clipboard history";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service.ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Service.Restart = "on-failure";
      Install.WantedBy = [ "graphical-session.target" ];
    };

    cliphist-image = {
      Unit = {
        Description = "Store image clipboard history";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service.ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Service.Restart = "on-failure";
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
