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

  deferDir = "/var/lib/ups-deferred"; # root: one marker per skipped unit

  # ExecCondition gate. Exit 1 = skip (not a failure, so no alert@ fires).
  # If NUT itself is broken, never block the job.
  onMains = pkgs.writeShellApplication {
    name = "ups-on-mains";
    runtimeInputs = [nut pkgs.coreutils];
    text = ''
      unit="$1"
      status=$(upsc ${upsAddr} ups.status 2> /dev/null) || exit 0
      if [[ " $status " == *" OB "* ]]; then
        echo "on battery (ups.status: $status): deferring $unit until mains returns"
        touch "${deferDir}/$unit"
        exit 1
      fi
    '';
  };

  catchUp = pkgs.writeShellApplication {
    name = "ups-catch-up";
    runtimeInputs = [pkgs.coreutils config.systemd.package];
    text = ''
      rm -f ${runDir}/catch-up # PathExists re-triggers until it is gone
      shopt -s nullglob
      for marker in ${deferDir}/*; do
        unit=$(basename "$marker")
        rm -f "$marker"
        echo "mains back: starting deferred $unit"
        systemctl start --no-block "$unit"
      done
    '';
  };

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

      # Once per shutdown: LOWBATT and FSD/SHUTDOWN all fire on the way down.
      alert_shutdown() {
        [[ -e ${stateDir}/shutdown-alerted ]] && exit 0
        touch ${stateDir}/shutdown-alerted
        ups_fields
        ${alert} --priority 5 --tag ups "''${fields[@]}" -- "low battery: shutting down"
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
        lowbatt)
          # With ignorelb the driver raises LB from charge/runtime alone, so LB
          # can be set on mains while recharging after a low-battery shutdown
          # (e.g. "OL CHRG LB" at boot). Only page when actually on battery.
          status=$(upsc ${upsAddr} ups.status 2> /dev/null) || status=""
          [[ " $status " == *" OB "* ]] || exit 0
          alert_shutdown
          ;;
        fsd) # forced shutdown (also SHUTDOWN): unconditional
          alert_shutdown
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
    AT SHUTDOWN * EXECUTE fsd
    AT NOCOMM * EXECUTE nocomm
    AT COMMOK * EXECUTE commok
    AT REPLBATT * EXECUTE replbatt
  '';

  textfileDir = config.services.nixosMetrics.textfileDirectory;
  passwordFile = config.age.secrets.nut-upsmon.path;

  # upscmd takes the password on argv; this runs as root on a localhost-only
  # upsd, briefly, so that is accepted.
  upscmd = cmd: ''upscmd -u upsmon -p "$(< ${passwordFile})" ${upsAddr} ${cmd}'';

  selftest = pkgs.writeShellApplication {
    name = "ups-selftest";
    runtimeInputs = [nut pkgs.coreutils];
    text = ''
      ${upscmd "test.battery.start.quick"}

      # ups.test.result reads "No test initiated" until the UPS picks it up.
      sleep 15
      result="unknown"
      for _ in $(seq 24); do
        result=$(upsc ${upsAddr} ups.test.result 2> /dev/null) || result="unknown"
        [[ $result == "In progress" ]] || break
        sleep 5
      done

      passed=0
      [[ $result == "Done and passed" ]] && passed=1

      out="${textfileDir}/ups.prom"
      tmp=$(mktemp "$out.XXXXXX")
      cat > "$tmp" << EOF
      # HELP ups_selftest_passed 1 if the last UPS battery self-test passed.
      # TYPE ups_selftest_passed gauge
      ups_selftest_passed $passed
      # HELP ups_selftest_last_run_timestamp_seconds When the last UPS self-test ran.
      # TYPE ups_selftest_last_run_timestamp_seconds gauge
      ups_selftest_last_run_timestamp_seconds $(date +%s)
      EOF
      chmod 0644 "$tmp"
      mv "$tmp" "$out"

      # ups.test.result is a closed set from the driver (ADR-0018-safe).
      if [[ $passed -eq 0 ]]; then
        ${alert} --priority 3 --tag ups --field "result=$result" --field "check=upsc ${upsAddr} ups.test.result" -- "UPS self-test did not pass"
      fi
    '';
  };

  # ExecCondition gate for ups-selftest: only test on mains with a charged
  # battery, else a drained battery after an outage gives a false "did not pass".
  # Exit 1 = skip, not a failure (no alert@).
  selftestReady = pkgs.writeShellApplication {
    name = "ups-selftest-ready";
    runtimeInputs = [nut pkgs.coreutils];
    text = ''
      if ! status=$(upsc ${upsAddr} ups.status 2> /dev/null); then
        echo "upsc failed: skipping self-test"
        exit 1
      fi
      charge=$(upsc ${upsAddr} battery.charge 2> /dev/null) || charge=""
      if [[ " $status " != *" OL "* || " $status " == *" OB "* ]]; then
        echo "not on mains (ups.status: $status): skipping self-test"
        exit 1
      fi
      if [[ ! $charge =~ ^[0-9]+$ ]] || ((charge < 95)); then
        echo "battery charge '$charge' not numeric or below 95: skipping self-test"
        exit 1
      fi
    '';
  };

  beeperOff = pkgs.writeShellApplication {
    name = "ups-beeper-off";
    runtimeInputs = [nut pkgs.coreutils];
    text = ''
      # upsd/driver may still be settling at boot; some CyberPower firmware
      # forgets this setting after a power cycle, hence every boot.
      for _ in $(seq 12); do
        if ${upscmd "beeper.disable"}; then exit 0; fi
        sleep 5
      done
      exit 1
    '';
  };
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
    assertions =
      map (unit: {
        assertion = (config.systemd.services.${unit}.serviceConfig.ExecStart or null) != null;
        message = "services.upsMonitor.deferOnBattery: ${unit} is not a service with an ExecStart on this host.";
      })
      cfg.deferOnBattery;

    age.secrets.nut-upsmon = {
      file = ../../secrets/nut-upsmon.age;
      mode = "0400";
    };

    power.ups = {
      enable = true;
      mode = "standalone";

      users.upsmon = {
        inherit passwordFile;
        instcmds = ["beeper.disable" "test.battery.start.quick"];
        upsmon = "primary";
      };

      schedulerRules = "${upsschedConf}";

      upsmon = {
        # COMMBAD is deliberately absent: it fires on every upsd/driver restart.
        # COMMOK is only used to re-arm the NOCOMM alert and never alerts.
        # NOCOMM means the link has been down for NOCOMMWARNTIME (300 s).
        # A forced shutdown on a primary emits SHUTDOWN (not reliably FSD), so
        # both map to the fsd event; the shutdown-alerted flag dedups the page.
        settings.NOTIFYFLAG =
          map (event: [event "SYSLOG+EXEC"])
          ["ONBATT" "ONLINE" "LOWBATT" "FSD" "SHUTDOWN" "NOCOMM" "COMMOK" "REPLBATT"];

        # Gives the priority-5 Alert's curl time to reach ntfy before
        # `shutdown now` (default 5 s).
        settings.FINALDELAY = 15;

        monitor.${cfg.ups} = {
          system = "${cfg.ups}@localhost";
          user = "upsmon";
          type = "primary";
          powerValue = 1;
        };
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d ${runDir} 0750 ${nutUser} ${nutGroup} -"
        "d ${stateDir} 0750 ${nutUser} ${nutGroup} -"
        "d ${deferDir} 0755 root root -"
      ];

      services =
        {
          # Sends the Resolution (and triggers catch-up) after a low-battery
          # shutdown, when no ONLINE event will ever arrive.
          ups-boot-check = {
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
          ups-catch-up = {
            description = "Start jobs deferred while on battery";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe catchUp;
            };
          };
          ups-selftest = {
            description = "Quick UPS battery self-test";
            after = ["upsd.service" "upsdrv.service"];
            onFailure = ["alert@%n.service"];
            serviceConfig = {
              Type = "oneshot";
              ExecCondition = lib.getExe selftestReady;
              ExecStart = lib.getExe selftest;
            };
          };
          ups-beeper-off = {
            description = "Disable the UPS beeper (Alerts replace it)";
            after = ["upsd.service" "upsdrv.service"];
            wantedBy = ["multi-user.target"];
            onFailure = ["alert@%n.service"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe beeperOff;
            };
          };
        }
        # "+": run the gate with full privileges whatever the unit's User=.
        // lib.genAttrs cfg.deferOnBattery (unit: {
          serviceConfig.ExecCondition = ["+${lib.getExe onMains} ${unit}"];
        });

      timers.ups-boot-check = {
        wantedBy = ["timers.target"];
        timerConfig.OnBootSec = "2min";
      };

      # 01:00 on the 1st: clear of auto-deploy (00:00 +30m) and restic
      # (02:00 +2h; Sunday prune 04:00 +2h). Not Persistent: never at boot
      # after an outage.
      timers.ups-selftest = {
        wantedBy = ["timers.target"];
        timerConfig.OnCalendar = "*-*-01 01:00:00";
      };

      paths.ups-catch-up = {
        wantedBy = ["paths.target"];
        pathConfig.PathExists = "${runDir}/catch-up";
      };
    };

    services.prometheus = {
      # nut_exporter only exports what is listed (its default list omits runtime).
      exporters.nut = {
        enable = true;
        listenAddress = "127.0.0.1";
        nutVariables = [
          "battery.charge"
          "battery.runtime"
          "battery.voltage"
          "input.voltage"
          "output.voltage"
          "ups.load"
          "ups.realpower.nominal"
          "ups.status"
        ];
      };

      # Prometheus runs on this same host (monitoring.nix). The exporter serves
      # /ups_metrics, not /metrics, and needs ?ups=<name>.
      scrapeConfigs = lib.mkIf config.services.prometheus.enable [
        {
          job_name = "nut";
          metrics_path = "/ups_metrics";
          params.ups = [cfg.ups];
          static_configs = [
            {
              targets = ["127.0.0.1:9199"];
              labels.host = config.networking.hostName;
            }
          ];
        }
      ];
    };
  };
}
