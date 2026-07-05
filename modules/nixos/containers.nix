{ lib, pkgs, ... }:

{
  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers.backend = "podman";

  # Podman's NixOS module still defines an empty prune timer when pruning is
  # disabled. Keep it out of the unit set so Distrobox pet containers persist.
  systemd.timers.podman-prune.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    buildah
    dive
    distrobox
    distroshelf
    podlet
    podman-compose
    podman-desktop
    podman-tui
    skopeo
  ];
}
