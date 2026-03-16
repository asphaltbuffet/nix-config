{...}: {
  imports = [
    ./hardware-configuration.nix

    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/laptop/x1carbon.nix
  ];

  networking.hostName = "snallygaster";
  system.stateVersion = "26.05";
}
