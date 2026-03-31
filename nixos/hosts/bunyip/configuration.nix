{...}: {
  imports = [
    ./hardware-configuration.nix

    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "bunyip";

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/bunyip to pause without editing this file.
  system.autoDeploy.enable = true;
}
