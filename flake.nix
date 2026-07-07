{
  description = "Jason's NixOS laptop configurations";

  inputs = {
    # nixos-unstable: matches the Plasma 6.7 currently in use, and carries the
    # freshest kernel/firmware for the Panther Lake 13 Pro arriving Aug 2026.
    # flake.lock pins the exact revision; roll back from the boot menu if an
    # update misbehaves. Fallback if unstable gets too spicy: nixos-26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
          # Per-host modules: nixos-hardware profile, fingerprint reader,
          # and the desktop choice (Plasma on the laptops, one desktop per
          # VM guest).
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs username hostname;
          };
          modules = extraModules ++ [
            ./modules/nixos/base.nix
            ./modules/nixos/containers.nix
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

      # QEMU/KVM guests run under virt-manager on the laptops — one VM per
      # desktop environment, because desktops sharing an install (or a
      # $HOME) contaminate each other's cursors, fonts, and settings.
      mkVmHost =
        { hostname, desktopModule }:
        mkHost {
          inherit hostname;
          extraModules = [
            ./modules/nixos/vm-guest.nix
            desktopModule
          ];
        };
    in
    {
      nixosConfigurations = {
        framework-amd-ai-300 = mkHost {
          hostname = "framework-amd-ai-300";
          extraModules = [
            "${nixos-hardware}/framework/13-inch/amd-ai-300-series"
            ./modules/nixos/desktop-plasma.nix
            ./modules/nixos/fingerprint.nix
          ];
        };

        framework-intel-core-ultra = mkHost {
          hostname = "framework-intel-core-ultra";
          extraModules = [
            "${nixos-hardware}/framework/13-inch/intel-core-ultra-series3"
            ./modules/nixos/desktop-plasma.nix
            ./modules/nixos/fingerprint.nix
          ];
        };

        # The GNOME guest keeps its historical name: the installed VM's
        # hostname is baked in, and rebuild.sh matches on hostname.
        qemu-vm = mkVmHost {
          hostname = "qemu-vm";
          desktopModule = ./modules/nixos/desktop-gnome.nix;
        };

        vm-cosmic = mkVmHost {
          hostname = "vm-cosmic";
          desktopModule = ./modules/nixos/desktop-cosmic.nix;
        };

        vm-hyprland = mkVmHost {
          hostname = "vm-hyprland";
          desktopModule = ./modules/nixos/desktop-hyprland.nix;
        };

        vm-cinnamon = mkVmHost {
          hostname = "vm-cinnamon";
          desktopModule = ./modules/nixos/desktop-cinnamon.nix;
        };
      };
    };
}
