# nixos/common/ups.nix
# UPS monitoring for a host with a USB-attached UPS (bunyip). NUT runs
# standalone: driver, upsd (localhost only) and upsmon all on this host.
#
# The host defines the physical device as power.ups.ups.<name> and sets
#   services.upsMonitor = { enable = true; ups = "<name>"; deferOnBattery = [...]; };
# On low battery upsmon shuts the host down and killpower cuts the UPS outlets,
# so the host boots again when mains returns (needs BIOS "power on after AC loss").
{
  config,
  lib,
  ...
}: let
  cfg = config.services.upsMonitor;
in {
  options.services.upsMonitor = {
    enable = lib.mkEnableOption "NUT UPS monitoring, Alerts and on-battery job deferral";

    ups = lib.mkOption {
      type = lib.types.str;
      default = "cyberpower";
      description = "Name of the power.ups.ups.<name> device this host is powered by.";
    };

    deferOnBattery = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Service names (without .service) skipped while on battery and started once mains is back.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.nut-upsmon = {
      file = ../../secrets/nut-upsmon.age;
      mode = "0400";
    };

    power.ups = {
      enable = true;
      mode = "standalone";

      users.upsmon = {
        passwordFile = config.age.secrets.nut-upsmon.path;
        upsmon = "primary";
      };

      upsmon.monitor.${cfg.ups} = {
        system = "${cfg.ups}@localhost";
        user = "upsmon";
        type = "primary";
        powerValue = 1;
      };
    };
  };
}
