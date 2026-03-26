{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../profiles/laptop/x1carbon.nix

    ../../common/users.nix

    ../../profiles/base.nix
  ];

  networking.hostName = "snallygaster";

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05";

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/snallygaster to pause without editing this file.
  system.autoDeploy.enable = true;
}
