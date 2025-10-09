{
  description = "My programs and configurations";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-index-database,
      home-manager,
      nixos-hardware,
      systems,
      ...
    }:
    let
      inherit (self) outputs;
      perSystem = callback: nixpkgs.lib.getAttrs (import systems) (system: callback (pkgs system));
      flakePath = config: "${config.home.homeDirectory}/nix-config";
      pkgs = system: import nixpkgs { inherit system; };
      extraSpecialArgs = { inherit flakePath inputs outputs; };
    in
    {
      nixosConfigurations = {
        "kushtaka" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            nixos-hardware.nixosModules.lenovo-thinkpad-t14
            ./nixos/kushtaka/configuration.nix

            nix-index-database.nixosModules.nix-index
            { programs.nix-index-database.comma.enable = true; }

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                backupFileExtension = "backup";
                users.grue = import ./home/users/grue/kushtaka.nix;
                users.jsquats = import ./home/users/jsquats/kushtaka.nix;
                users.sukey = import ./home/users/sukey/kushtaka.nix;
              };
            }
          ];
        };
        "wendigo" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            nixos-hardware.nixosModules.lenovo-thinkpad-t14
            ./nixos/wendigo/configuration.nix

            nix-index-database.nixosModules.nix-index
            { programs.nix-index-database.comma.enable = true; }

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                backupFileExtension = "backup";
                users.grue = import ./home/users/grue/wendigo.nix;
              };
            }
          ];
        };
        # add additional systems here...
      };

      inherit home-manager;
      inherit (home-manager) packages;
    };

}
