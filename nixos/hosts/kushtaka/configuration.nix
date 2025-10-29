{ inputs, config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/gaming.nix
    ../../profiles/laptop/t14.nix
  ];

  networking.hostName = "kushtaka"; # Define your hostname.

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
