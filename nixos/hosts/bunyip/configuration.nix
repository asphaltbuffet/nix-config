{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/server.nix
    ../../common/wherefolk.nix
    ../../common/stirling-pdf.nix
    ../../common/micasa.nix
    ../../common/ups.nix
  ];

  networking.hostName = "bunyip";
  system.stateVersion = "26.11";

  system.autoDeploy.enable = true;

  # CyberPower CP1500AVR on USB; bunyip is its only load (CONTEXT.md: Mains failure).
  power.ups.ups.cyberpower = {
    driver = "usbhid-ups";
    port = "auto";
    description = "CyberPower CP1500AVR";
    directives = [
      "vendorid = 0764"
      "productid = 0501"
      # Poll instead of relying on the interrupt pipe, which stalls on CyberPower HID.
      "pollonly"
      # Shut down with ~5 min of runtime left instead of at the UPS's own LB:
      # ignorelb makes the driver raise LB from these thresholds.
      "ignorelb"
      "override.battery.charge.low = 20"
      "override.battery.runtime.low = 300"
      # killpower: outlets off 60 s after shutdown, back on 120 s after mains
      # returns. ondelay must exceed offdelay; whole minutes suit CyberPower.
      "offdelay = 60"
      "ondelay = 120"
    ];
  };

  services = {
    upsMonitor.enable = true;

    # 2012 Aptio 4 firmware has no ESRT, so UEFI capsule updates are impossible
    # (and Biostar never published to LVFS); silence fwupd's warning about it.
    fwupd.daemonSettings.DisabledPlugins = ["uefi_capsule"];

    resticBackup = {
      home.enable = true;
      srv.enable = true;
    };

    # Kingston UV400 firmware fails SMART health status, error/self-test logs
    # and self-tests, and attribute reads fail intermittently. Under -a smartd
    # sends a false smartd-bunyip alert daily; with attribute-only checks a
    # failed read at startup makes smartd exit, unmonitoring every disk. So
    # smartd ignores it (DEVICESCAN skips it too); its attributes and wear are
    # still collected by smartctl-exporter for Grafana.
    smartd.devices = [
      {
        device = "/dev/disk/by-id/ata-KINGSTON_SUV400S37240G_50026B776605C0FB";
        options = "-d ignore";
      }
    ];
  };
}
