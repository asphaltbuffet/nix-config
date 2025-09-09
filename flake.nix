{
  description = "My programs and configurations";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
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

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                backupFileExtension = "backup";
                users.grue = import ./home/users/grue/kushtaka.nix;
              };
            }
          ];
        };
        "wendigo" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            nixos-hardware.nixosModules.lenovo-thinkpad-t14
            ./nixos/wendigo/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
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
