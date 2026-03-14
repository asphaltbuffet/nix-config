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
      default = pkgs.mkShell {
        packages = [
          pkgs.nixd # nix LSP (understands flake option types)
          pkgs.alejandra # nix formatter
          pkgs.statix # nix linter
          pkgs.deadnix # find unused nix code
          agenix.packages.${system}.default # secrets management
          pkgs.just # command runner
          pkgs.phoronix-test-suite # benchmarking
          pkgs.p7zip # benchmark dependency
          pkgs.python3 # required by hookify claude plugin
          pkgs.nodejs # provides npx for MCP servers (e.g. context7)
        ];
        # phoronix-test-suite compiles test suites at runtime and needs these
        # as buildInputs so their headers/libs are on the compiler search paths
        buildInputs = [
          pkgs.libaio # required by pts/fio
          pkgs.openssl # required by pts/openssl (libressl lacks expected paths)
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

    # Runnable apps: `nix run .#benchmark`
    apps = forAllSystems (system: let
      pkgs = mkPkgs system;
      benchmarkScript = pkgs.writeShellApplication {
        name = "benchmark";
        runtimeInputs = [
          pkgs.phoronix-test-suite
          pkgs.p7zip
          pkgs.libaio
          pkgs.openssl
          pkgs.zlib
          pkgs.gcc
        ];
        text = ''
          # Phoronix checks for headers at hardcoded /usr/include paths which don't
          # exist in the Nix store. NO_EXTERNAL_DEPENDENCIES=1 skips that pre-flight
          # check. C_INCLUDE_PATH/LIBRARY_PATH let gcc find headers+libs at compile time;
          # LD_LIBRARY_PATH lets the dynamic linker find them at runtime.
          export NO_EXTERNAL_DEPENDENCIES=1
          export C_INCLUDE_PATH="${pkgs.libaio}/include:${pkgs.openssl.dev}/include:${pkgs.zlib.dev}/include''${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
          export LIBRARY_PATH="${pkgs.libaio}/lib:${pkgs.openssl.out}/lib:${pkgs.zlib}/lib''${LIBRARY_PATH:+:$LIBRARY_PATH}"
          export LD_LIBRARY_PATH="${pkgs.libaio}/lib:${pkgs.openssl.out}/lib:${pkgs.zlib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          phoronix-test-suite run pts/compress-7zip pts/ramspeed pts/fio pts/blake2 pts/openssl
        '';
      };
    in {
      benchmark = {
        type = "app";
        program = "${benchmarkScript}/bin/benchmark";
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
