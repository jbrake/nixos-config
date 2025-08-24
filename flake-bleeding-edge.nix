{
  description = "Modular NixOS configuration with bleeding-edge packages";

  inputs = {
    # Main nixpkgs - using unstable for newer packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Even fresher packages from master (use with caution)
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    
    # KDE packages from their own repo (often fresher)
    nixpkgs-kde.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    
    # Hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixpkgs-master, nixpkgs-kde, nixos-hardware, ... }@inputs: 
  let
    hwMods = nixos-hardware.nixosModules;
    hardwareModule = if builtins.hasAttr "framework-amd-ai-300-series" hwMods
      then hwMods.framework-amd-ai-300-series
      else if builtins.hasAttr "framework-13-amd-ai-300-series" hwMods
      then hwMods.framework-13-amd-ai-300-series
      else throw "No matching Framework AMD AI 300 series hardware module found in nixos-hardware.";
    # Overlay to use master packages selectively
    overlay-master = final: prev: {
      # Example: use specific packages from master
      # brave = inputs.nixpkgs-master.legacyPackages.${prev.system}.brave;
      # vscode = inputs.nixpkgs-master.legacyPackages.${prev.system}.vscode;
    };
    
    # Overlay for KDE packages
    overlay-kde = final: prev: {
      # Use KDE packages from the smaller, more frequently updated channel
      kdePackages = inputs.nixpkgs-kde.legacyPackages.${prev.system}.kdePackages;
    };
  in
  {
    nixosConfigurations = {
      # Jason's Framework laptop with bleeding-edge packages
      jason-framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          ./hosts/jason-framework/configuration.nix
          {
            nixpkgs.overlays = [ overlay-master overlay-kde ];
            # Allow unfree packages
            nixpkgs.config.allowUnfree = true;
            # Use latest kernel from unstable
            boot.kernelPackages = nixpkgs.legacyPackages.x86_64-linux.linuxPackages_latest;
          }
        ];
      };
      
      # Lanna's laptop - stable packages for reliability
      lanna-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/lanna-laptop/configuration.nix
          {
            nixpkgs.config.allowUnfree = true;
          }
        ];
      };
      
      # VM for testing
      vm-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/vm-test/configuration.nix
          {
            nixpkgs.overlays = [ overlay-master overlay-kde ];
            nixpkgs.config.allowUnfree = true;
          }
        ];
      };
    };
  };
}
