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

  # 2012 Aptio 4 firmware has no ESRT, so UEFI capsule updates are impossible
  # (and Biostar never published to LVFS); silence fwupd's warning about it.
  services.fwupd.daemonSettings.DisabledPlugins = ["uefi_capsule"];
}
