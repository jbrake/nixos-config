{ ... }:

# Hyprland VM guest. All the shared VM plumbing lives in
# modules/nixos/vm-guest.nix, wired in via the flake.
{
  imports = [ ./hardware-configuration.nix ];
}
