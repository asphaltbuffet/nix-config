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
  pkgs,
  ...
}: let
  cfg = config.services.upsMonitor;
  nut = config.power.ups.package;
  alert = lib.getExe config.alerts.package;
  upsAddr = "${cfg.ups}@localhost";
  nutUser = config.power.ups.upsmon.user;
  nutGroup = config.power.ups.upsmon.group;

  runDir = "/run/upssched"; # nutmon: upssched pipe/lock + catch-up trigger
  stateDir = "/var/lib/ups-events"; # nutmon: survives a low-battery shutdown

  # upssched CMDSCRIPT, runs as nutmon. Alert fields are numbers or closed-set
  # values only (ADR-0018).
  upsEvent = pkgs.writeShellApplication {
    name = "ups-event";
    runtimeInputs = [nut pkgs.coreutils];
    text = ''
      fields=()
      ups_fields() {
        local charge runtime load
        charge=$(upsc ${upsAddr} battery.charge 2> /dev/null) || charge="?"
        runtime=$(upsc ${upsAddr} battery.runtime 2> /dev/null) || runtime="?"
        load=$(upsc ${upsAddr} ups.load 2> /dev/null) || load="?"
        if [[ $runtime =~ ^[0-9]+$ ]]; then runtime="$((runtime / 60)) min"; fi
        fields=(--field "charge=$charge%" --field "runtime=$runtime" --field "load=$load%")
      }

      # The Resolution pairs with an on-battery Alert that was actually sent.
      resolve() {
        rm -f ${stateDir}/shutdown-alerted
        if [[ -e ${stateDir}/onbatt-alerted ]]; then
          rm -f ${stateDir}/onbatt-alerted
          ups_fields
          ${alert} --priority 3 --tag ups --tag resolved "''${fields[@]}" -- "$1"
        fi
      }

      case "''${1:-}" in
        onbatt) # on battery for 30 s
          # A flap within the 30 s mains-stable window re-arms the onbatt timer;
          # the open Alert already covers it.
          [[ -e ${stateDir}/onbatt-alerted ]] && exit 0
          touch ${stateDir}/onbatt-alerted
          ups_fields
          ${alert} --priority 4 --tag ups "''${fields[@]}" -- "on battery: mains failure"
          ;;
        mains-stable) # back on mains for 30 s
          touch ${runDir}/catch-up # ups-catch-up.path starts deferred jobs
          resolve "mains restored"
          ;;
        lowbatt | fsd) # upsmon raises both on the way down; alert once
          [[ -e ${stateDir}/shutdown-alerted ]] && exit 0
          touch ${stateDir}/shutdown-alerted
          ups_fields
          ${alert} --priority 5 --tag ups "''${fields[@]}" -- "low battery: shutting down"
          ;;
        nocomm) # NUT re-notifies every NOCOMMWARNTIME; alert once per outage
          [[ -e ${runDir}/nocomm-alerted ]] && exit 0
          touch ${runDir}/nocomm-alerted
          ${alert} --priority 3 --tag ups --field "check=upsc ${upsAddr}" -- "UPS communication lost"
          ;;
        commok) # link recovered: re-arm the NOCOMM alert, send nothing
          rm -f ${runDir}/nocomm-alerted
          ;;
        replbatt)
          ${alert} --priority 3 --tag ups --field "check=sudo systemctl start ups-selftest" -- "UPS battery needs replacing"
          ;;
        boot) # after a low-battery shutdown, mains is back if we are running on OL
          status=$(upsc ${upsAddr} ups.status 2> /dev/null) || exit 0
          [[ " $status " == *" OL "* ]] || exit 0
          touch ${runDir}/catch-up
          resolve "mains restored after shutdown"
          ;;
        *)
          echo "ups-event: unknown event: ''${1:-}" >&2
          exit 2
          ;;
      esac
    '';
  };

  upsschedConf = pkgs.writeText "upssched.conf" ''
    CMDSCRIPT ${lib.getExe upsEvent}
    PIPEFN ${runDir}/upssched.pipe
    LOCKFN ${runDir}/upssched.lock

    AT ONBATT * START-TIMER onbatt 30
    AT ONBATT * CANCEL-TIMER mains-stable
    AT ONLINE * CANCEL-TIMER onbatt
    AT ONLINE * START-TIMER mains-stable 30
    AT LOWBATT * EXECUTE lowbatt
    AT FSD * EXECUTE fsd
    AT NOCOMM * EXECUTE nocomm
    AT COMMOK * EXECUTE commok
    AT REPLBATT * EXECUTE replbatt
  '';
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

      schedulerRules = "${upsschedConf}";

      # COMMBAD is deliberately absent: it fires on every upsd/driver restart.
      # COMMOK is only used to re-arm the NOCOMM alert and never alerts.
      # NOCOMM means the link has been down for NOCOMMWARNTIME (300 s).
      upsmon.settings.NOTIFYFLAG =
        map (event: [event "SYSLOG+EXEC"])
        ["ONBATT" "ONLINE" "LOWBATT" "FSD" "NOCOMM" "COMMOK" "REPLBATT"];

      upsmon.monitor.${cfg.ups} = {
        system = "${cfg.ups}@localhost";
        user = "upsmon";
        type = "primary";
        powerValue = 1;
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d ${runDir} 0750 ${nutUser} ${nutGroup} -"
        "d ${stateDir} 0750 ${nutUser} ${nutGroup} -"
      ];

      # Sends the Resolution (and triggers catch-up) after a low-battery
      # shutdown, when no ONLINE event will ever arrive.
      services.ups-boot-check = {
        description = "Resolve a pre-shutdown on-battery Alert once mains is back";
        after = ["upsd.service" "upsdrv.service" "network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          User = nutUser;
          Group = nutGroup;
          ExecStart = "${lib.getExe upsEvent} boot";
        };
      };
      timers.ups-boot-check = {
        wantedBy = ["timers.target"];
        timerConfig.OnBootSec = "2min";
      };
    };
  };
}
