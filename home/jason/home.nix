{
  inputs,
  lib,
  pkgs,
  username,
  hostname,
  ...
}:

{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.plasma = {
    # Only the laptops run Plasma; keep plasma-manager from writing KDE
    # config into the VM guests' homes (a stray KDE cursor-theme setting
    # once broke the GNOME VM's cursor).
    enable = lib.hasPrefix "framework-" hostname;
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
    configFile."powerdevil.notifyrc" = {
      "Event\\/pluggedin".Action = "";
      "Event\\/unplugged".Action = "";
    };
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    BROWSER = "brave";
    EDITOR = "vim";
    TERMINAL = "ghostty";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    };
  };

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
    '';
    functions.fish_prompt = ''
      set -l last_status $status

      set_color green
      echo -n "$USER "
      set_color $fish_color_cwd
      echo -n (prompt_pwd)
      set_color normal

      set -l vcs (fish_vcs_prompt)
      test -n "$vcs"; and echo -n " $vcs"

      if test $last_status -ne 0
        set_color red
        echo -n " [$last_status]"
        set_color normal
      end

      echo -n "> "
    '';
  };

  xdg.configFile."alacritty/alacritty.toml".source = ./alacritty/alacritty.toml;
  xdg.configFile."ghostty/config".source = ./ghostty/config;
  xdg.configFile."ghostty/themes/jason-nord".source = ./ghostty/themes/jason-nord;

  home.packages = with pkgs; [
    claude-code
    codex
    nodejs
    python3
    unrar
    uv
  ];
}
