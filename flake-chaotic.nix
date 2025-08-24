{
  description = "NixOS configuration with Chaotic-Nyx for freshest packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    
    # Chaotic-Nyx provides very fresh, pre-built packages
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixos-hardware, chaotic, ... }@inputs: let
    hwMods = nixos-hardware.nixosModules;
    hardwareModule = if builtins.hasAttr "framework-amd-ai-300-series" hwMods
      then hwMods.framework-amd-ai-300-series
      else if builtins.hasAttr "framework-13-amd-ai-300-series" hwMods
      then hwMods.framework-13-amd-ai-300-series
      else throw "No matching Framework AMD AI 300 series hardware module found in nixos-hardware.";
  in {
    nixosConfigurations = {
      # Jason's Framework laptop with Chaotic packages
      jason-framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          chaotic.nixosModules.default
          ./hosts/jason-framework/configuration.nix
          {
            # Enable Chaotic cache for pre-built binaries
            nix.settings = {
              substituters = [
                "https://cache.nixos.org"
                "https://chaotic-nyx.cachix.org"
              ];
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12DfYThuhnf52Zbs="
              ];
            };
            
            # Use Chaotic's fresh packages
            chaotic.mesa-git.enable = true;  # Latest Mesa drivers
            # chaotic.linux-cachyos.enable = true;  # Performance-optimized kernel
          }
        ];
      };
      
      # Lanna's laptop - stable, no chaotic
      lanna-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/lanna-laptop/configuration.nix
        ];
      };
      
      # VM for testing
      vm-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/vm-test/configuration.nix
        ];
      };
    };
  };
}
