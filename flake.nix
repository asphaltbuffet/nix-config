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

    # NURs
    nur.url = "github:nix-community/NUR";
    goreleaser-nur.url = "github:goreleaser/nur";
    charmbracelet-nur = {
      url = "github:charmbracelet/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    agenix,
    alejandra,
    home-manager,
    nix-index-database,
    nixos-hardware,
    nur,
    goreleaser-nur,
    charmbracelet-nur,
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
            goreleaser = import goreleaser-nur {pkgs = prev;};
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
            alejandra
            home-manager
            nixos-hardware
            goreleaser-nur
            charmbracelet-nur
            nur
            ;
        };
        modules = [
          nur.modules.nixos.default
          ({config, ...}: {config = {nixpkgs.overlays = overlays;};})
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
      nixVim = pkgs.neovim.override {
        configure = {
          customRC = ''
            set number relativenumber
            set expandtab tabstop=2 shiftwidth=2
            lua << EOF
            vim.g.mapleader = ','
            -- nil LSP setup
            vim.lsp.enable('nil_ls')
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover)
            vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format() end)
            EOF
          '';
          packages.nix = with pkgs.vimPlugins; {
            start = [
              vim-nix # nix syntax highlighting
              nvim-lspconfig # LSP configurations
              plenary-nvim # required by many plugins
              telescope-nvim # fuzzy finder
            ];
          };
        };
      };
    in {
      default = pkgs.mkShell {
        packages = [
          nixVim # neovim configured for nix development
          pkgs.nil # nix LSP server
          pkgs.alejandra # nix formatter
          pkgs.statix # nix linter
          agenix.packages.${system}.default
          pkgs.just
        ];
        shellHook = ''
          echo "nix-config dev shell"
          echo "  nvim   - neovim with nix LSP"
          echo "  nil    - nix language server"
          echo "  statix - nix linter"
          echo "  just   - command runner"
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
