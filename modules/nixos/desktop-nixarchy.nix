{ inputs, username, ... }:
{
  imports = [ inputs.nixarchy.nixosModules.nixarchy ];

  programs.nixarchy = {
    enable = true;
    user = username;
    flake = "/home/${username}/Documents/repos/nixos-config";
  };
  # The shared container profile provides Docker-compatible Podman.
  virtualisation.docker.enable = false;
  services.displayManager.defaultSession = "omarchy";
}
