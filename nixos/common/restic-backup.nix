# nixos/common/restic-backup.nix
# Restic backups to encrypted per-host repositories on the NAS (ADR-0022).
#
#   services.resticBackup.home.enable  one snapshot per user home -> /nas/public/backups/<host>
#   services.resticBackup.srv.enable   /srv data disk             -> /nas/public/backups/<host>-srv
#
# Repos are `restic init`ed by hand (docs/references/restic-backup-sop.md);
# nothing here creates one. An unreachable NAS is a *skip* on hosts that sleep
# and a *failure* on Always-on hosts.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.resticBackup;
  hostName = config.networking.hostName;
  alwaysOn = config.host.alwaysOn;
  nasRoot = "/nas/public/backups";
  textfileDir = config.services.nixosMetrics.textfileDirectory;
  excludeFile = ./restic-backup/excludes.txt;
  alert = "${config.alerts.package}/bin/alert";

  metrics = pkgs.writeShellApplication {
    name = "restic-metrics";
    runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.jq];
    text = builtins.readFile ./restic-backup/metrics.sh;
  };

  # Shared prelude: repo + password env, and the reachability probe. Reading
  # the repo's config file triggers the NFS automount.
  # Hosts that sleep retry the probe (a laptop waking at 02:00 races Wi-Fi);
  # Always-on hosts probe once and fail.
  probeAttempts =
    if alwaysOn
    then 1
    else 6;
  probeCmd = ''timeout 15 test -f "$RESTIC_REPOSITORY/config"'';
  unreachableMsg = ''echo "restic repository $RESTIC_REPOSITORY unreachable (NAS off-network or repo not initialised)"'';
  probe =
    if alwaysOn
    then ''
      if ! ${probeCmd}; then
        ${unreachableMsg}
        exit 1
      fi
    ''
    else ''
      reachable=0
      for attempt in $(seq 1 ${toString probeAttempts}); do
        if ${probeCmd}; then
          reachable=1
          break
        fi
        if [ "$attempt" -lt ${toString probeAttempts} ]; then
          sleep 20
        fi
      done
      if [ "$reachable" -eq 0 ]; then
        ${unreachableMsg}
        exit 0
      fi
    '';

  prelude = repo: ''
    export RESTIC_REPOSITORY=${nasRoot}/${repo}
    export RESTIC_PASSWORD_FILE=${config.age.secrets."restic-${repo}".path}
    ${probe}
  '';

  # `sudo restic-<repo> ...` for hands-on admin: repo, password and cache preset.
  mkAdminWrapper = repo:
    pkgs.writeShellScriptBin "restic-${repo}" ''
      export RESTIC_REPOSITORY=${lib.escapeShellArg "${nasRoot}/${repo}"}
      export RESTIC_PASSWORD_FILE=${lib.escapeShellArg config.age.secrets."restic-${repo}".path}
      export RESTIC_CACHE_DIR=${lib.escapeShellArg "/var/cache/restic-${repo}"}
      exec ${lib.getExe pkgs.restic} "$@"
    '';

  cacheConfig = repo: {
    CacheDirectory = "restic-${repo}";
    Environment = ["RESTIC_CACHE_DIR=/var/cache/restic-${repo}"];
  };

  mkBackupScript = {
    repo,
    jobs, # [{source, path, args}]
  }:
    pkgs.writeShellApplication {
      name = "restic-backup-${repo}";
      runtimeInputs = [pkgs.restic pkgs.jq pkgs.coreutils metrics];
      text = ''
        ${prelude repo}
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        rc=0

        run_job() { # source path [restic args...]
          local source=$1 path=$2 status=0
          shift 2
          if [ ! -d "$path" ]; then
            echo "skip $source: $path missing"
            return 0
          fi
          # Exit 3 = snapshot written but some files unreadable: still a success.
          restic backup --json --retry-lock 1h --tag "$source" "$@" "$path" \
            > "$tmp/out.json" || status=$?
          if { [ "$status" -eq 0 ] || [ "$status" -eq 3 ]; } &&
            jq -c 'select(.message_type=="summary")' "$tmp/out.json" > "$tmp/summary.json" &&
            [ -s "$tmp/summary.json" ]; then
            if ! restic-metrics backup-ok ${textfileDir} ${repo} "$source" "$tmp/summary.json"; then
              echo "recording metrics for $source failed" >&2
              restic-metrics backup-fail ${textfileDir} ${repo} "$source" || true
              rc=1
            fi
          else
            echo "backup of $source failed (restic exit $status)" >&2
            restic-metrics backup-fail ${textfileDir} ${repo} "$source"
            rc=1
          fi
        }

        ${lib.concatMapStringsSep "\n" (j: ''
            run_job ${lib.escapeShellArg j.source} ${lib.escapeShellArg j.path} ${lib.escapeShellArgs j.args}
          '')
          jobs}
        exit "$rc"
      '';
    };

  homeArgs = [
    "--one-file-system"
    "--exclude-caches"
    "--exclude-if-present"
    ".nobackup"
    "--exclude-file=${excludeFile}"
  ];

  mkBackupUnits = {
    repo,
    jobs,
    unitConfig ? {},
  }: {
    services."restic-backup-${repo}" = {
      description = "restic backup to ${nasRoot}/${repo}";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      onFailure = ["alert@%n.service"];
      inherit unitConfig;
      serviceConfig =
        {
          Type = "oneshot";
          ExecStart = lib.getExe (mkBackupScript {inherit repo jobs;});
          Nice = 19;
          IOSchedulingClass = "idle";
          PrivateTmp = true;
        }
        // cacheConfig repo;
    };
    timers."restic-backup-${repo}" = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
    };
  };

  homeRepo = hostName;
  srvRepo = "${hostName}-srv";

  homeUnits = mkBackupUnits {
    repo = homeRepo;
    jobs =
      map (u: {
        source = u;
        path = config.users.users.${u}.home;
        args = homeArgs;
      })
      cfg.home.users;
  };

  srvUnits = mkBackupUnits {
    repo = srvRepo;
    jobs = [
      {
        source = "srv";
        path = "/srv";
        args = ["--one-file-system" "--exclude" "/srv/lost+found"];
      }
    ];
    # /srv is mounted nofail: if the disk is gone, fail instead of snapshotting
    # an empty directory on the root disk.
    unitConfig.RequiresMountsFor = ["/srv"];
  };

  mkPruneScript = repo:
    pkgs.writeShellApplication {
      name = "restic-prune-${repo}";
      runtimeInputs = [pkgs.restic pkgs.jq pkgs.coreutils metrics];
      text = ''
        ${prelude repo}

        fail() {
          restic-metrics repo-fail ${textfileDir} ${repo}
          exit 1
        }

        restic forget --prune --retry-lock 1h \
          --keep-daily 7 --keep-weekly 4 --keep-monthly 6 || fail

        # A corrupt repo is worse than a missed night: priority 4 (the unit
        # failure then also sends the generic alert; the duplicate is accepted).
        # The metric is written first; a failing alert must not change the outcome.
        if ! restic check --retry-lock 1h --read-data-subset=5%; then
          restic-metrics repo-fail ${textfileDir} ${repo}
          ${alert} --priority 4 --tag restic --field "repo=${repo}" -- restic check failed || true
          exit 1
        fi

        raw=$(restic stats --mode raw-data --json | jq -er '.total_size') || fail
        restic-metrics repo-ok ${textfileDir} ${repo} "$raw"
      '';
    };

  mkPruneUnits = repo: {
    services."restic-prune-${repo}" = {
      description = "restic prune + check of ${nasRoot}/${repo}";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      onFailure = ["alert@%n.service"];
      serviceConfig =
        {
          Type = "oneshot";
          ExecStart = lib.getExe (mkPruneScript repo);
          Nice = 19;
          IOSchedulingClass = "idle";
          PrivateTmp = true;
        }
        // cacheConfig repo;
    };
    timers."restic-prune-${repo}" = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "Sun *-*-* 04:00:00";
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
    };
  };
in {
  options.services.resticBackup = {
    home = {
      enable = lib.mkEnableOption "nightly restic Home backup of every user home (ADR-0022)";
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
        description = "Users whose homes are snapshotted, one snapshot each.";
      };
    };
    srv.enable = lib.mkEnableOption "nightly restic Data-disk backup of /srv (ADR-0022)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.home.enable {
      age.secrets."restic-${homeRepo}" = {
        file = ../../secrets + "/restic-${homeRepo}.age";
        mode = "0400";
      };
      environment.systemPackages = [(mkAdminWrapper homeRepo)];
      systemd = {
        services = homeUnits.services // (mkPruneUnits homeRepo).services;
        timers = homeUnits.timers // (mkPruneUnits homeRepo).timers;
      };
    })
    (lib.mkIf cfg.srv.enable {
      age.secrets."restic-${srvRepo}" = {
        file = ../../secrets + "/restic-${srvRepo}.age";
        mode = "0400";
      };
      environment.systemPackages = [(mkAdminWrapper srvRepo)];
      systemd = {
        services = srvUnits.services // (mkPruneUnits srvRepo).services;
        timers = srvUnits.timers // (mkPruneUnits srvRepo).timers;
      };
    })
  ];
}
