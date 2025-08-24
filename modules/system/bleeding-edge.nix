{ config, pkgs, lib, inputs, ... }:

{
  options.system.useBleedingEdge = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Use bleeding-edge packages from nixpkgs master";
  };

  config = lib.mkIf config.system.useBleedingEdge {
    # Override specific packages with fresher versions
    nixpkgs.overlays = [
      (final: prev: {
        # Get packages from master branch
        # Uncomment the packages you want from master:
        
        # Browsers
        # brave = inputs.nixpkgs-master.legacyPackages.${prev.system}.brave;
        # firefox = inputs.nixpkgs-master.legacyPackages.${prev.system}.firefox;
        
        # Development tools
        # vscode = inputs.nixpkgs-master.legacyPackages.${prev.system}.vscode;
        # git = inputs.nixpkgs-master.legacyPackages.${prev.system}.git;
        
        # KDE Plasma packages - get latest
        # kdePackages = inputs.nixpkgs-master.legacyPackages.${prev.system}.kdePackages;
      })
    ];
    
    # Use latest kernel
    boot.kernelPackages = pkgs.linuxPackages_latest;
    
    # Enable experimental features
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    
    # More aggressive garbage collection for frequent updates
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}