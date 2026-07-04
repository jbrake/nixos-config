{
  inputs,
  pkgs,
  username,
  ...
}:

{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.plasma = {
    enable = true;
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    BROWSER = "brave";
    EDITOR = "vim";
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
  };

  xdg.configFile."alacritty/alacritty.toml".source = ./alacritty/alacritty.toml;

  home.packages = with pkgs; [
    claude-code
    codex
    nodejs
    python3
    unrar
    uv
  ];
}
