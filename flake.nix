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

    # RetroDECK is intentionally distributed as a Flatpak. This module keeps
    # that one external application declarative without treating every Flatpak
    # installed by hand as NixOS-owned state.
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Polished Hyprland shell with a native Home Manager module. It follows
    # the system package set so Hyprland, Quickshell, and portals stay aligned.
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
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
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.${system};

      mkHost =
        {
          hostname,
          desktop,
          profile ? hostname,
          username ? "jason",
          homeModule ? ./home/jason/home.nix,
          # Per-host modules: nixos-hardware profile, fingerprint reader,
          # and the desktop choice (one reusable profile per laptop desktop,
          # one desktop per VM guest).
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
            inputs.nix-flatpak.nixosModules.nix-flatpak
            ./modules/nixos/emulation.nix
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

      laptopDesktopModules = {
        plasma = ./modules/nixos/desktop-plasma.nix;
        gnome = ./modules/nixos/desktop-gnome-laptop.nix;
        cinnamon = ./modules/nixos/desktop-cinnamon-laptop.nix;
        cosmic = ./modules/nixos/desktop-cosmic-laptop.nix;
        hyprland = ./modules/nixos/desktop-hyprland-laptop.nix;
      };

      mkFrameworkLaptopProfiles =
        {
          hostname,
          hardwareModule,
          enableBackup ? false,
          fingerprintResetMode ? "when-missing",
        }:
        lib.mapAttrs' (
          desktop: desktopModule:
          let
            profile = if desktop == "plasma" then hostname else "${hostname}-${desktop}";
          in
          lib.nameValuePair profile (mkLaptopHost {
            inherit
              hostname
              desktop
              profile
              desktopModule
              ;
            extraModules = [
              hardwareModule
              ./modules/nixos/fingerprint.nix
              {
                jbrake.frameworkFingerprint.resetMode = fingerprintResetMode;
              }
            ]
            ++ lib.optional enableBackup {
              jbrake.resticBackup = {
                enable = true;
                nasUser = "restic-jason";
                nasShare = "restic-jason";
              };
            };
          })
        ) laptopDesktopModules;
    in
    {
      nixosConfigurations =
        (mkFrameworkLaptopProfiles {
          hostname = "framework-amd-ai-300";
          hardwareModule = "${nixos-hardware}/framework/13-inch/amd-ai-300-series";
          enableBackup = true;
          # This controller is dedicated to the Goodix reader on the AMD
          # laptop, so resetting it after every wake is safe.
          fingerprintResetMode = "always";
        })
        // (mkFrameworkLaptopProfiles {
          hostname = "framework-intel-core-ultra";
          hardwareModule = "${nixos-hardware}/framework/13-inch/intel-core-ultra-series3";
          enableBackup = true;
        })
        // {
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

      # Build every laptop desktop role on deployed AMD hardware in CI. Nix
      # also evaluates all Intel and VM configurations during flake checks.
      checks.${system} = lib.mapAttrs' (
        desktop: _:
        let
          profile = if desktop == "plasma" then "framework-amd-ai-300" else "framework-amd-ai-300-${desktop}";
        in
        lib.nameValuePair profile self.nixosConfigurations.${profile}.config.system.build.toplevel
      ) laptopDesktopModules;
    };
}
