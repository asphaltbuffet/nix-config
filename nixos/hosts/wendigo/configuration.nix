{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../profiles/laptop/t14.nix

    ../../common/users.nix
    ../../common/netmon.nix

    ../../profiles/base.nix
    ../../profiles/gaming.nix
  ];

  networking.hostName = "wendigo"; # Define your hostname.

  # Home-network health sampler. Only runs on the home network (guarded by the
  # default gateway matching services.netmon.homeGateway); silent when roaming.
  services.netmon.enable = true;

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/wendigo to pause without editing this file.
  system.autoDeploy.enable = true;
}
