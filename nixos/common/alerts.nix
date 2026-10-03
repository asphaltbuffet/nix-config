# nixos/common/alerts.nix
# Fleet-wide push-on-error Alerts via the public ntfy.sh topic (ADR-0018).
#
# `alert [-p 1-5] [-t TAG]... [-f KEY=VALUE]... [-n] [--] <text>` publishes
# title "<host>: <text>" with a body of "key: value" lines plus a "config:"
# line identifying the running system. The topic is world-readable: fields
# carry only closed-set values, opaque IDs and commands — never logs or other
# free-form text. Units opt in to failure alerts with:
#   systemd.services.<name>.onFailure = ["alert@%n.service"];
# There is deliberately no heartbeat: silence means nothing was detected.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.alerts;
  host = config.networking.hostName;

  alert = pkgs.writeShellApplication {
    name = "alert";
    runtimeInputs = [pkgs.curl];
    text = ''
      usage() {
        echo "usage: alert [-p 1-5] [-t TAG]... [-f KEY=VALUE]... [-n] [--] <text>..." >&2
        exit 2
      }

      priority=3
      tags=()
      fields=()
      dry_run=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -p | --priority) [[ $# -ge 2 ]] || usage; priority="$2"; shift 2 ;;
          -t | --tag) [[ $# -ge 2 ]] || usage; tags+=("$2"); shift 2 ;;
          -f | --field)
            [[ $# -ge 2 ]] || usage
            if [[ ! "$2" =~ ^[a-z]+= || "$2" == *$'\n'* ]]; then
              echo "alert: field must be KEY=VALUE (lowercase key, single line), got: $2" >&2
              exit 2
            fi
            fields+=("$2")
            shift 2
            ;;
          -n | --dry-run) dry_run=1; shift ;;
          --) shift; break ;;
          -*) echo "alert: unknown option: $1" >&2; exit 2 ;;
          *) break ;;
        esac
      done

      if [[ $# -eq 0 ]]; then
        usage
      fi
      if [[ ! "$priority" =~ ^[1-5]$ ]]; then
        echo "alert: priority must be 1-5, got: $priority" >&2
        exit 2
      fi

      tags+=("${host}")
      tag_header=$(IFS=,; echo "''${tags[*]}")
      title="${host}: $*"
      # Identify the running system at send time (not baked in, so the
      # script doesn't change per commit).
      system_hash=$(basename "$(readlink -f /run/current-system)" | cut -c1-8)
      system_version=$(cat /run/current-system/nixos-version 2> /dev/null || echo unknown)
      fields+=("config=$system_hash / nixos $system_version")
      body=""
      for field in "''${fields[@]}"; do
        body+=$(printf '%-7s %s' "''${field%%=*}:" "''${field#*=}")$'\n'
      done
      body="''${body%$'\n'}"
      url="https://ntfy.sh/${cfg.topic}"

      if [[ $dry_run -eq 1 ]]; then
        printf 'POST %s\nTitle: %s\nPriority: %s\nTags: %s\n\n%s\n' "$url" "$title" "$priority" "$tag_header" "$body"
        exit 0
      fi

      curl -fsS --retry 3 \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tag_header" \
        -d "$body" \
        "$url" > /dev/null
    '';
  };

  # OnFailure= hook: systemd passes the failed run's result as MONITOR_* env
  # vars (closed sets / opaque IDs). Unset when started by hand (alert@test).
  alertUnitFailed = pkgs.writeShellApplication {
    name = "alert-unit-failed";
    text = ''
      unit="$1"
      fields=(--field "result=''${MONITOR_SERVICE_RESULT:-unknown} (status ''${MONITOR_EXIT_STATUS:-?})")
      if [[ -n "''${MONITOR_INVOCATION_ID:-}" ]]; then
        fields+=(--field "logs=journalctl -u $unit --invocation=$MONITOR_INVOCATION_ID")
      else
        fields+=(--field "logs=journalctl -u $unit -b")
      fi
      exec ${alert}/bin/alert --tag "$unit" "''${fields[@]}" -- "$unit" failed
    '';
  };
in {
  options.alerts = {
    topic = lib.mkOption {
      type = lib.types.str;
      default = "asphaltbuffet-nix-fleet";
      description = "Public ntfy.sh topic every host publishes Alerts to. Plaintext by design (ADR-0018).";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = alert;
      description = "The `alert` CLI, for hooks that run without a useful PATH (e.g. smartd -M exec).";
    };
  };

  config = {
    environment.systemPackages = [alert];

    # Template: alert@<unit>.service. %i is the failed unit's full name.
    systemd.services."alert@" = {
      description = "ntfy Alert for failed unit %i";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${alertUnitFailed}/bin/alert-unit-failed %i";
      };
    };
  };
}
