{
  description = "My programs and configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    alejandra = {
      url = "github:kamadorueda/alejandra/4.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    charmbracelet-nur = {
      url = "github:charmbracelet/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NURs
    nur.url = "github:nix-community/NUR";

    nixos-autodeploy = {
      url = "github:hlsb-fulda/nixos-autodeploy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    agenix,
    alejandra,
    home-manager,
    nixos-hardware,
    nur,
    ...
  }: let
    # Supported systems - add more as needed (e.g., "aarch64-linux" for ARM servers)
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    overlays = [
      (_final: prev: {
        nur = import nur {
          nurpkgs = prev;
          pkgs = prev;
          repoOverrides = {
          };
        };
      })
    ];

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

    mkHost = hostname: system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            self
            inputs
            nixpkgs
            agenix
            home-manager
            nixos-hardware
            nur
            ;
        };
        modules = [
          nur.modules.nixos.default
          agenix.nixosModules.default
          ({...}: {config = {nixpkgs.overlays = overlays;};})
          {
            environment.systemPackages = [
              agenix.packages.${system}.default
              alejandra.defaultPackage.${system}
            ];
          }
          ./nixos/hosts/${hostname}/configuration.nix
        ];
      };

    mkInstaller = system:
      (nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self inputs nixpkgs agenix;
        };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          {environment.systemPackages = [agenix.packages.${system}.default];}
          ./nixos/installer/configuration.nix
        ];
      }).config.system.build.isoImage;

    # discover all host directories under nixos/hosts
    hostnames = builtins.attrNames (builtins.readDir ./nixos/hosts);
  in {
    nixosConfigurations = builtins.listToAttrs (
      map (h: {
        name = h;
        value = mkHost h "x86_64-linux";
      })
      hostnames
    );

    packages = forAllSystems (system: {
      installer = mkInstaller system;
    });

    # Development shell for working on this config
    devShells = forAllSystems (system: let
      pkgs = mkPkgs system;
    in {
      default = import ./shell.nix {inherit pkgs system agenix;};
    });

    # Formatter for `nix fmt`
    formatter = forAllSystems (system: alejandra.defaultPackage.${system});

    # Checks for `nix flake check`
    checks = forAllSystems (system: {
      formatting = (mkPkgs system).runCommand "check-formatting" {} ''
        ${alejandra.defaultPackage.${system}}/bin/alejandra --check ${self} > $out
      '';
    });
  };
}
