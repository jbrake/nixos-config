{
  description = "Jason's NixOS laptop configurations";

  inputs = {
    # Unstable carries current Plasma, kernels, and firmware for both Framework
    # generations. flake.lock pins every input for reproducible builds.
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

    # AI CLIs come from dedicated, independently pinned flakes because they
    # generally package vendor releases sooner than nixpkgs-unstable.
    # Deliberately no nixpkgs follows (self-contained per upstream docs) and
    # no cachix substituter (local "build" is just fetch + patchelf).
    # Update independently of nixpkgs:
    #   nix flake update claude-code-nix codex-cli-nix
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkHost =
        {
          hostname,
          desktop,
          profile ? hostname,
          username ? "jason",
          homeModule ? ./home/jason/home.nix,
          # Per-host modules: nixos-hardware profile, fingerprint reader,
          # and the desktop choice (Plasma on the laptops, one desktop per
          # VM guest).
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              username
              hostname
              desktop
              profile
              ;
          };
          modules = extraModules ++ [
            ./modules/nixos/base.nix
            ./modules/nixos/backup.nix
            ./modules/nixos/containers.nix
            ./hosts/${hostname}/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  username
                  hostname
                  desktop
                  ;
              };
              home-manager.users.${username} = import homeModule;
            }
          ];
        };

      mkLaptopHost =
        {
          hostname,
          desktop,
          desktopModule,
          profile ? hostname,
          username ? "jason",
          homeModule ? ./home/jason/home.nix,
          extraModules ? [ ],
        }:
        mkHost {
          inherit
            hostname
            desktop
            profile
            username
            homeModule
            ;
          extraModules = [
            ./modules/nixos/laptop.nix
            ./modules/nixos/virtualization-host.nix
            ./modules/nixos/workstation-apps.nix
            ./modules/nixos/desktop-state.nix
            desktopModule
          ]
          ++ extraModules;
        };

      # QEMU/KVM guests run under virt-manager on the laptops — one VM per
      # desktop environment, because desktops sharing an install (or a
      # $HOME) contaminate each other's cursors, fonts, and settings.
      mkVmHost =
        {
          hostname,
          desktop,
          desktopModule,
          profile ? hostname,
        }:
        mkHost {
          inherit hostname desktop profile;
          extraModules = [
            ./modules/nixos/vm-guest.nix
            desktopModule
          ];
        };
    in
    {
      nixosConfigurations = {
        framework-amd-ai-300 = mkLaptopHost {
          hostname = "framework-amd-ai-300";
          desktop = "plasma";
          desktopModule = ./modules/nixos/desktop-plasma.nix;
          extraModules = [
            "${nixos-hardware}/framework/13-inch/amd-ai-300-series"
            ./modules/nixos/fingerprint.nix
            {
              jbrake.resticBackup = {
                enable = true;
                nasUser = "restic-jason";
                nasShare = "restic-jason";
              };
            }
          ];
        };

        # A clean GNOME alternative for the same physical machine. The output
        # name differs, but networking.hostName and the hardware module remain
        # those of framework-amd-ai-300.
        framework-amd-ai-300-gnome = mkLaptopHost {
          hostname = "framework-amd-ai-300";
          desktop = "gnome";
          profile = "framework-amd-ai-300-gnome";
          desktopModule = ./modules/nixos/desktop-gnome-laptop.nix;
          extraModules = [
            "${nixos-hardware}/framework/13-inch/amd-ai-300-series"
            ./modules/nixos/fingerprint.nix
            {
              jbrake.resticBackup = {
                enable = true;
                nasUser = "restic-jason";
                nasShare = "restic-jason";
              };
            }
          ];
        };

        framework-intel-core-ultra = mkLaptopHost {
          hostname = "framework-intel-core-ultra";
          desktop = "plasma";
          desktopModule = ./modules/nixos/desktop-plasma.nix;
          extraModules = [
            "${nixos-hardware}/framework/13-inch/intel-core-ultra-series3"
            ./modules/nixos/fingerprint.nix
          ];
        };

        # The GNOME guest keeps its historical name: the installed VM's
        # hostname is baked in, and rebuild.sh matches on hostname.
        qemu-vm = mkVmHost {
          hostname = "qemu-vm";
          desktop = "gnome";
          desktopModule = ./modules/nixos/desktop-gnome.nix;
        };

        vm-cosmic = mkVmHost {
          hostname = "vm-cosmic";
          desktop = "cosmic";
          desktopModule = ./modules/nixos/desktop-cosmic.nix;
        };

        vm-hyprland = mkVmHost {
          hostname = "vm-hyprland";
          desktop = "hyprland";
          desktopModule = ./modules/nixos/desktop-hyprland.nix;
        };

        vm-cinnamon = mkVmHost {
          hostname = "vm-cinnamon";
          desktop = "cinnamon";
          desktopModule = ./modules/nixos/desktop-cinnamon.nix;
        };
      };

      formatter.${system} = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          deadnix
          gitleaks
          lychee
          shellcheck
          statix
        ];
      };

      # Build both physical-laptop desktop profiles in CI. Nix also evaluates
      # every exported nixosConfiguration during `nix flake check`.
      checks.${system} = {
        framework-amd-ai-300 = self.nixosConfigurations.framework-amd-ai-300.config.system.build.toplevel;
        framework-amd-ai-300-gnome =
          self.nixosConfigurations.framework-amd-ai-300-gnome.config.system.build.toplevel;
      };
    };
}
