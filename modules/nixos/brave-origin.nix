{ inputs, pkgs, ... }:

let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Brave Origin is not in the pinned stable package set yet. Keep the browser
  # on the existing unstable pin until it reaches NixOS 26.05.
  environment.systemPackages = [ unstable."brave-origin" ];
}
