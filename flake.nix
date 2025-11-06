{
  description = "My programs and configurations";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    alejandra.url = "github:kamadorueda/alejandra/4.0.0";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-index-database,
      alejandra,
      home-manager,
      nixos-hardware,
      systems,
      ...
    }:
    let
      systems = [ "x86_64-linux" ];

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ (import ./overlays) ];
          config.allowUnfree = true;
        };

      mkHost =
        hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              self
              inputs
              nixpkgs
              home-manager
              alejandra
              nixos-hardware
              ;
          };
          modules = [
            {
              environment.systemPackages = [alejandra.defaultPackage.${system}];
            }
            ./nixos/hosts/${hostname}/configuration.nix
          ];
        };

      # discover all host directories under nixos/hosts
      hostnames = builtins.attrNames (builtins.readDir ./nixos/hosts);

    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map (h: {
          name = h;
          value = mkHost h "x86_64-linux";
        }) hostnames
      );
    };
}
