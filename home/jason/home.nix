{
  inputs,
  lib,
  pkgs,
  username,
  hostname,
  desktop,
  ...
}:

let
  isLaptop = builtins.elem hostname [
    "framework-amd-ai-300"
    "framework-intel-core-ultra"
  ];

  isLaptopHyprland = desktop == "hyprland" && isLaptop;

  tone3000 = pkgs.callPackage ../../packages/tone3000.nix { };

  # KWin stores touchpad settings per physical device. Keep the preferences
  # portable and isolate the hardware identity here, so a future laptop only
  # needs one additional device entry.
  touchpadPreferences = {
    enable = true;
    disableWhileTyping = false;
    leftHanded = false;
    middleButtonEmulation = false;
    pointerSpeed = 0;
    accelerationProfile = "default";
    naturalScroll = true;
    tapToClick = false;
    tapAndDrag = false;
    tapDragLock = false;
    scrollMethod = "twoFingers";
    scrollSpeed = 0.3;
    rightClickMethod = "twoFingers";
  };

  touchpadDevices = {
    "framework-intel-core-ultra" = {
      name = "PIXA3854:00 093A:1343 Touchpad";
      vendorId = "093a";
      productId = "1343";
    };
  };
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
  ]
  ++ lib.optionals isLaptopHyprland [
    inputs.caelestia-shell.homeManagerModules.default
    ./hyprland.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.firefox = {
    enable = true;
    policies.ExtensionSettings = {
      "uBlock0@raymondhill.net" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        installation_mode = "force_installed";
      };
      "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
        installation_mode = "force_installed";
      };
      "addon@darkreader.org" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
        installation_mode = "force_installed";
      };
    };
  };

  programs.plasma = {
    # Keep Plasma Manager completely inactive in GNOME and the other desktop
    # profiles. A stray KDE cursor-theme setting once broke the GNOME VM.
    enable = desktop == "plasma";
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
    input.touchpads =
      if desktop == "plasma" && builtins.hasAttr hostname touchpadDevices then
        [ (touchpadDevices.${hostname} // touchpadPreferences) ]
      else
        [ ];
    configFile = {
      "powerdevil.notifyrc" = {
        "Event\\/pluggedin".Action = "";
        "Event\\/unplugged".Action = "";
      };
    }
    // lib.optionalAttrs (desktop == "plasma" && hostname == "framework-amd-ai-300") {
      # These IDs belong to Jason's existing hand-arranged panel. Keep the
      # machine-specific override away from other Plasma installations.
      "plasma-org.kde.plasma.desktop-appletsrc" = {
        "Containments][25][Applets][43][Configuration][Appearance".use24hFormat = 2;
      };
    };
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    BROWSER = "brave-origin";
    EDITOR = "vim";
    TERMINAL = "ghostty";
  };

  xdg.mimeApps = {
    enable = true;
    # Claude Code's desktop integration registers this handler by editing
    # mimeapps.list in place; declare it so the overwrite below keeps it.
    associations.added = {
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
    defaultApplications = {
      "text/html" = "brave-origin.desktop";
      "x-scheme-handler/http" = "brave-origin.desktop";
      "x-scheme-handler/https" = "brave-origin.desktop";
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    }
    // lib.optionalAttrs (desktop == "plasma") {
      "inode/directory" = "org.kde.dolphin.desktop";
    }
    // lib.optionalAttrs (desktop == "gnome") {
      "inode/directory" = "org.gnome.Nautilus.desktop";
    }
    // lib.optionalAttrs (desktop == "cinnamon") {
      "inode/directory" = "nemo.desktop";
    }
    // lib.optionalAttrs (desktop == "cosmic") {
      "inode/directory" = "com.system76.CosmicFiles.desktop";
    }
    // lib.optionalAttrs isLaptopHyprland {
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };
  # Desktops and apps rewrite mimeapps.list behind home-manager's back, and
  # the backup-before-replace dance jams once a .hm-backup exists (failed a
  # rebuild once). Overwrite instead: ad-hoc default-app changes get reverted
  # at rebuild; anything worth keeping belongs in defaultApplications above.
  xdg.configFile."mimeapps.list".force = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "Jason Brake";
      email = "pnut001@gmail.com";
    };
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      fish_add_path -m $HOME/.local/bin
    '';
    interactiveShellInit = ''
      set -g fish_greeting
    ''
    + lib.optionalString isLaptopHyprland ''
      test -r ~/.local/state/caelestia/sequences.txt; and cat ~/.local/state/caelestia/sequences.txt
    '';
    shellAbbrs = {
      gs = "git status --short --branch";
      gd = "git diff";
      gds = "git diff --staged";
      gl = "git log --oneline --graph --decorate -20";
      lg = "lazygit";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      format = "$username$hostname$directory$git_branch$git_commit$git_state$git_status$nix_shell$python$nodejs$rust$cmd_duration$status$line_break$character";
      directory = {
        style = "bold cyan";
        truncation_length = 3;
        truncate_to_repo = true;
        read_only = " ro";
      };
      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = "[$symbol$branch(:$remote_branch)]($style) ";
      };
      git_commit = {
        tag_disabled = false;
      };
      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = "yellow";
        conflicted = "[conflict:\${count}](bold red) ";
        untracked = "[?\${count}](cyan) ";
        modified = "[!\${count}](yellow) ";
        staged = "[+\${count}](green) ";
        renamed = "[»\${count}](purple) ";
        deleted = "[✘\${count}](red) ";
        stashed = "[stash:\${count}](blue) ";
        ahead = "[↑\${count}](green) ";
        behind = "[↓\${count}](red) ";
        diverged = "[↑\${ahead_count}↓\${behind_count}](red) ";
      };
      nix_shell = {
        symbol = "nix ";
        format = "[$symbol$state]($style) ";
      };
      python.symbol = "py ";
      nodejs.symbol = "node ";
      rust.symbol = "rs ";
      cmd_duration = {
        min_time = 2000;
        format = "[took $duration](dimmed white) ";
      };
      status = {
        disabled = false;
        format = "[exit $status](bold red) ";
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold purple)";
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
    ];
  };
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.lazygit.enable = true;

  programs.konsole = {
    enable = desktop == "plasma";
    defaultProfile = "Jason Nord";
    profiles."Jason Nord" = {
      colorScheme = "Jason Nord";
      command = "${pkgs.fish}/bin/fish";
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };
      extraConfig = {
        General = {
          TerminalColumns = 133;
          TerminalRows = 31;
        };
        Scrolling = {
          HistoryMode = 1;
          HistorySize = 10000;
        };
      };
    };
    # Match the existing Ghostty palette.
    customColorSchemes."Jason Nord" = {
      General = {
        Description = "Jason Nord";
        Opacity = 0.94;
        Blur = true;
      };
      Background.Color = "46,52,64";
      BackgroundIntense.Color = "46,52,64";
      Foreground.Color = "216,222,233";
      ForegroundIntense.Color = "236,239,244";
      Color0.Color = "59,66,82";
      Color0Intense.Color = "76,86,106";
      Color1.Color = "191,97,106";
      Color1Intense.Color = "191,97,106";
      Color2.Color = "163,190,140";
      Color2Intense.Color = "163,190,140";
      Color3.Color = "235,203,139";
      Color3Intense.Color = "235,203,139";
      Color4.Color = "129,161,193";
      Color4Intense.Color = "129,161,193";
      Color5.Color = "180,142,173";
      Color5Intense.Color = "180,142,173";
      Color6.Color = "136,192,208";
      Color6Intense.Color = "143,188,187";
      Color7.Color = "229,233,240";
      Color7Intense.Color = "236,239,244";
    };
  };

  xdg.configFile."alacritty/alacritty.toml".source = ./alacritty/alacritty.toml;
  xdg.configFile."ghostty/config".source = ./ghostty/config;
  xdg.configFile."ghostty/themes/jason-nord".source = ./ghostty/themes/jason-nord;

  # The upstream installer writes factory presets into the user's config
  # directory; expose the immutable packaged copies there instead.
  home.file = lib.optionalAttrs isLaptop {
    ".config/TONE3000/Presets/Factory".source = "${tone3000}/share/tone3000/factory-presets";
  };

  home.packages =
    # From dedicated flakes, not nixpkgs — see the inputs comment in flake.nix.
    (map (input: input.packages.${pkgs.stdenv.hostPlatform.system}.default) [
      inputs.claude-code-nix
      inputs.codex-cli-nix
    ])
    ++ (with pkgs; [
      nodejs
      python3
      unrar
      uv
    ]);
}
