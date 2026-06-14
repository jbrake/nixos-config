{
  description = "Jason's NixOS laptop configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "jason";

      mkHost =
        {
          hostname,
          hardwareModule,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs username hostname;
          };
          modules = [
            (import hardwareModule)
            ./modules/nixos/base.nix
            ./modules/nixos/desktop-plasma.nix
            ./hosts/${hostname}/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.extraSpecialArgs = {
                inherit inputs username hostname;
              };
              home-manager.users.${username} = import ./home/jason/home.nix;
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        framework-amd-ai-300 = mkHost {
          hostname = "framework-amd-ai-300";
          hardwareModule = "${nixos-hardware}/framework/13-inch/amd-ai-300-series";
        };

        framework-intel-core-ultra = mkHost {
          hostname = "framework-intel-core-ultra";
          hardwareModule = "${nixos-hardware}/framework/13-inch/intel-core-ultra-series3";
        };
      };

      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit inputs username;
          hostname = "standalone";
        };
        modules = [ ./home/jason/home.nix ];
      };
    };
}
