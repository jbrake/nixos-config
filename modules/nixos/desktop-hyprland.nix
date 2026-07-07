{ pkgs, ... }:

# Hyprland for the vm-hyprland guest. This is the bare compositor plus a
# usable starter kit; the actual rice (hyprland.conf, waybar, wallpaper,
# animations) belongs in home-manager per-desktop config when it grows.
{
  programs.hyprland.enable = true;

  # Minimal TUI greeter; Hyprland has no display manager of its own.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
      user = "greeter";
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    brave
    ghostty
    # Hyprland's default config spawns kitty (SUPER+Q); keep it until a
    # riced config takes over.
    kitty
    waybar
    wofi
  ];
}
