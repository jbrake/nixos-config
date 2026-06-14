{ lib, pkgs, ... }:

let
  kdeConfigSnapshot = ./kde/config;
  kdeDataSnapshot = ./kde/data;
in
{
  home.packages = with pkgs; [
    capitaine-cursors
    rsync
  ];

  home.activation.restoreKdeSnapshot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    marker="$HOME/.local/state/nixos-config/kde-snapshot-applied"

    if [ ! -e "$marker" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state/nixos-config"
      $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --chmod=Du+rwx,Dgo-rwx,Fu+rw,Fgo-rwx "${kdeConfigSnapshot}/" "$HOME/.config/"
      $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --chmod=Du+rwx,Dgo-rwx,Fu+rw,Fgo-rwx "${kdeDataSnapshot}/" "$HOME/.local/share/"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/touch "$marker"
    fi
  '';
}
