{
  description = "Modular NixOS configuration with switchable desktop environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs: let
    hwMods = nixos-hardware.nixosModules;
    hardwareModule = if builtins.hasAttr "framework-amd-ai-300-series" hwMods
      then hwMods.framework-amd-ai-300-series
      else if builtins.hasAttr "framework-13-amd-ai-300-series" hwMods
      then hwMods.framework-13-amd-ai-300-series
      else throw "No matching Framework AMD AI 300 series hardware module found in nixos-hardware.";
  in {
    nixosConfigurations = {
      # Jason's Framework laptop - GNOME variant
      jason-framework-gnome = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          ./hosts/jason-framework/configuration.nix
          ./hosts/jason-framework/desktops/gnome.nix
        ];
      };
      
      # Jason's Framework laptop - KDE Plasma variant
      jason-framework-plasma = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          ./hosts/jason-framework/configuration.nix
          ./hosts/jason-framework/desktops/plasma.nix
        ];
      };
      
      # Jason's Framework laptop - XFCE variant
      jason-framework-xfce = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          ./hosts/jason-framework/configuration.nix
          ./hosts/jason-framework/desktops/xfce.nix
        ];
      };
      
      # Jason's Framework laptop - Hyprland variant
      jason-framework-hyprland = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          ./hosts/jason-framework/configuration.nix
          ./hosts/jason-framework/desktops/hyprland.nix
        ];
      };
      
      # Jason's Framework laptop - Sway variant
      jason-framework-sway = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          hardwareModule
          ./hosts/jason-framework/configuration.nix
          ./hosts/jason-framework/desktops/sway.nix
        ];
      };

      # Legacy compatibility - defaults to GNOME
      jason-framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          ./hosts/jason-framework/configuration.nix
          ./hosts/jason-framework/desktops/gnome.nix
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
