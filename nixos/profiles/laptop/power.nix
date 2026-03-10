# nixos/profiles/laptop/power.nix
# Power management for ThinkPad T14 Gen 1 laptops.
# TLP and power-profiles-daemon are mutually exclusive; KDE Plasma enables PPD
# by default, so we explicitly disable it here.
{
  pkgs,
  lib,
  ...
}: {
  services.power-profiles-daemon.enable = lib.mkForce false;

  services.tlp = {
    enable = true;
    settings = {
      # CPU scaling governor and energy/performance policy
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Turbo boost: on when plugged in, off on battery
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Platform profiles (Intel Mode 2 power management)
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # NVMe power saving
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # WiFi power saving (Intel AX201)
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # Runtime power management for USB and PCI devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # Battery care: keep charge between 20-80% to extend long-term health.
      # These limits apply via ThinkPad ACPI and are preserved across reboots.
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Suspend on lid close regardless of power state
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
    IdleAction = "suspend";
    IdleActionSec = "30min";
  };
}
