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

  metrics = pkgs.writeShellApplication {
    name = "restic-metrics";
    runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.jq];
    text = builtins.readFile ./restic-backup/metrics.sh;
  };

  # Shared prelude: repo + password env, and the reachability probe. Reading
  # the repo's config file triggers the NFS automount.
  prelude = repo: ''
    export RESTIC_REPOSITORY=${nasRoot}/${repo}
    export RESTIC_PASSWORD_FILE=${config.age.secrets."restic-${repo}".path}
    if ! timeout 15 test -f "$RESTIC_REPOSITORY/config"; then
      echo "restic repository $RESTIC_REPOSITORY unreachable (NAS off-network or repo not initialised)"
      exit ${
      if alwaysOn
      then "1"
      else "0"
    }
    fi
  '';

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
            restic-metrics backup-ok ${textfileDir} ${repo} "$source" "$tmp/summary.json"
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
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe (mkBackupScript {inherit repo jobs;});
        Nice = 19;
        IOSchedulingClass = "idle";
        PrivateTmp = true;
      };
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
      systemd = {inherit (homeUnits) services timers;};
    })
    (lib.mkIf cfg.srv.enable {
      age.secrets."restic-${srvRepo}" = {
        file = ../../secrets + "/restic-${srvRepo}.age";
        mode = "0400";
      };
      systemd = {inherit (srvUnits) services timers;};
    })
  ];
}
