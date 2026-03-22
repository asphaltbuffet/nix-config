{...}: {
  imports = [
    ./hardware-configuration.nix

    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/laptop/x1carbon.nix
  ];

  networking.hostName = "snallygaster";
  system.stateVersion = "26.05";

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # See .autodeploy-skip/snallygaster to pause without editing this file.
  system.autoDeploy.enable = true;
}
