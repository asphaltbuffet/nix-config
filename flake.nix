{
  description = "My programs and configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "";
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
      (final: prev: {
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

    # Development shell for working on this config
    devShells = forAllSystems (system: let
      pkgs = mkPkgs system;
    in {
      default = pkgs.mkShell {
        packages = [
          pkgs.nixd # nix LSP (understands flake option types)
          pkgs.alejandra # nix formatter
          pkgs.statix # nix linter
          pkgs.deadnix # find unused nix code
          agenix.packages.${system}.default # secrets management
          pkgs.just # command runner
          pkgs.python3 # required by hookify claude plugin
          pkgs.nodejs # provides npx for MCP servers (e.g. context7)
        ];
        shellHook = ''
          echo "nix-config dev shell"
          echo "  nixd    - nix language server"
          echo "  alejandra / statix / deadnix - format, lint, dead-code"
          echo "  agenix  - secrets management"
          echo "  just    - run: just <build|switch|test|fmt|check>"
          echo "  npx     - node package runner (for MCP servers)"
        '';
      };
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
