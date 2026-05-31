{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "bunyip";
  system.stateVersion = "26.11";

  system.autoDeploy.enable = true;
}
