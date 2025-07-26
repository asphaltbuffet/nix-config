{
  description = "My programs and configurations";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs = { nixpkgs, home-manager, nixos-hardware, ... }: {
    homeConfigurations = {
      "grue@kushtaka" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          username = "grue";
          hostname = "kushtaka";
        };
        modules = [
          ./home/kushtaka.nix
        ];
      };
    };

    nixosConfigurations = {
      "kushtaka" = nixpkgs.lib.nixosSystem {
        system = "x86_64";
        modules = [
          nixos-hardware.nixosModules.lenovo-thinkpad-t14
          ./nixos/kushtaka/configuration.nix
          ./nixos/kushtaka/hardware-configuration.nix
        ];
      };
    };

    inherit home-manager;
    inherit (home-manager) packages;
  };

}
