{
  description = "Modular NixOS configuration with switchable desktop environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs: {
    nixosConfigurations = {
      # Jason's Framework laptop
      jason-framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          ./hosts/jason-framework/configuration.nix
        ];
      };
      
      # Lanna's laptop
      lanna-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          # Add hardware module here if her laptop is supported
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