{ pkgs, username, ... }:

{
  imports = [ ./kde.nix ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    BROWSER = "brave";
    EDITOR = "vim";
  };

  programs.git = {
    enable = true;
    userName = "Jason Brake";
    userEmail = "pnut001@gmail.com";
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
    nodejs
    npm
    python3
    unrar
    uv
  ];
}
