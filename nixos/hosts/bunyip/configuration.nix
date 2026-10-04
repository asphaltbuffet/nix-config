{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/server.nix
    ../../common/wherefolk.nix
  ];

  networking.hostName = "bunyip";
  system.stateVersion = "26.11";

  system.autoDeploy.enable = true;

  # 2012 Aptio 4 firmware has no ESRT, so UEFI capsule updates are impossible
  # (and Biostar never published to LVFS); silence fwupd's warning about it.
  services.fwupd.daemonSettings.DisabledPlugins = ["uefi_capsule"];

  # Kingston UV400 firmware fails SMART health status, error/self-test logs
  # and self-tests, and attribute reads fail intermittently. Under -a smartd
  # sends a false smartd-bunyip alert daily; with attribute-only checks a
  # failed read at startup makes smartd exit, unmonitoring every disk. So
  # smartd ignores it (DEVICESCAN skips it too); its attributes and wear are
  # still collected by smartctl-exporter for Grafana.
  services.smartd.devices = [
    {
      device = "/dev/disk/by-id/ata-KINGSTON_SUV400S37240G_50026B776605C0FB";
      options = "-d ignore";
    }
  ];
}
