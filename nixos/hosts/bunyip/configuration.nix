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

  # Kingston UV400 advertises SMART self-tests but aborts them ("scsi error
  # aborted command"), which smartd would report as a failed test every week.
  # Monitor attributes only; DEVICESCAN then skips this disk. Notify hook is
  # inherited from smartd's DEFAULT line (nixos/common/smartd.nix).
  services.smartd.devices = [
    {
      device = "/dev/disk/by-id/ata-KINGSTON_SUV400S37240G_50026B776605C0FB";
      options = "-a -o on -S on";
    }
  ];
}
