{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../profiles/laptop/t14.nix

    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/gaming.nix
  ];

  networking.hostName = "wendigo"; # Define your hostname.

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/wendigo to pause without editing this file.
  system.autoDeploy.enable = true;
}
