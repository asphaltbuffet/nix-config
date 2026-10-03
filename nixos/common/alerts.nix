# nixos/common/alerts.nix
# Fleet-wide push-on-error Alerts via the public ntfy.sh topic (ADR-0018).
#
# `alert [-p 1-5] [-t TAG]... [-n] [--] <text>` publishes "<host>: <text>".
# Titles only: never pipe logs or other free-form text into an alert — the
# topic is world-readable. Units opt in to failure alerts with:
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
        echo "usage: alert [-p 1-5] [-t TAG]... [-n] [--] <text>..." >&2
        exit 2
      }

      priority=3
      tags=()
      dry_run=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -p | --priority) [[ $# -ge 2 ]] || usage; priority="$2"; shift 2 ;;
          -t | --tag) [[ $# -ge 2 ]] || usage; tags+=("$2"); shift 2 ;;
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
      body="see journalctl on ${host}"
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
        ExecStart = "${alert}/bin/alert --tag %i -- %i failed";
      };
    };
  };
}
