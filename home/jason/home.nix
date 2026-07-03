{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    BROWSER = "brave";
    EDITOR = "vim";
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
