# nixos/common/netmon.nix
#
# Home-network health sampler for laptops/desktops.
#
# A systemd timer runs a small script every minute that pings the LAN gateway
# and a public anchor, times a DNS lookup, and records which interface / WiFi
# signal was in use — appending one JSON object per sample (JSON Lines) to a log
# for later analysis with jq.
#
# LAPTOP-SAFE: the sampler only runs when the machine is on its *home* network.
# It compares the current default gateway against `settings.homeGateway`; on any
# other network (coffee shop, tethered, VPN-only) it exits immediately and logs
# nothing. No manual toggling required.
#
# Analysis examples (default log: /var/log/netmon/netmon.jsonl):
#   jq -c 'select(.inet_loss_pct > 0 or .gw_loss_pct > 0)' netmon.jsonl   # drops
#   jq -s 'max_by(.inet_rtt_ms) | {ts, inet_rtt_ms}' netmon.jsonl         # worst RTT
#   jq -s 'map(select(.inet_rtt_ms!=null).inet_rtt_ms)|add/length' netmon.jsonl
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.netmon;

  netmon = pkgs.writeShellApplication {
    name = "netmon";
    runtimeInputs = with pkgs; [iputils dnsutils jq iproute2 gawk gnugrep coreutils networkmanager];
    text = ''
      set -uo pipefail

      HOME_GATEWAY="${cfg.homeGateway}"
      ANCHOR="${cfg.anchor}"
      DNS_NAME="${cfg.dnsName}"
      LOGFILE="${cfg.logFile}"
      PING_COUNT="${toString cfg.pingCount}"

      # Current default gateway (lowest-metric default route).
      GATEWAY=$(ip route | awk '/^default/ {m=($0 ~ /metric/ ? $NF : 0); print m, $3}' \
        | sort -n | awk 'NR==1{print $2}')

      # --- LAPTOP GUARD: only sample on the home network ---
      if [ "$GATEWAY" != "$HOME_GATEWAY" ]; then
        # Away from home (or offline). Do nothing, log nothing, succeed quietly.
        exit 0
      fi

      ping_stats() { # echoes "<loss> <rtt-or-empty>"
        local target="$1" out loss rtt
        out=$(ping -c "$PING_COUNT" -i 0.2 -w 5 "$target" 2>/dev/null) || true
        loss=$(printf '%s\n' "$out" | grep -oE '[0-9]+% packet loss' | grep -oE '^[0-9]+')
        rtt=$(printf '%s\n' "$out"  | awk -F'/' '/rtt|round-trip/ {print $5}')
        printf '%s %s' "''${loss:-100}" "''${rtt:-}"
      }

      DNS_MS=$(dig +tries=1 +time=2 "$DNS_NAME" 2>/dev/null | awk '/Query time:/ {print $4}')

      RIFACE=$(ip route | awk '/^default/ {m=($0 ~ /metric/ ? $NF : 0); print m, $3, $5}' \
        | sort -n | awk 'NR==1{print $3}')

      if [ -d "/sys/class/net/$RIFACE/wireless" ] || printf '%s' "$RIFACE" | grep -q '^wl'; then
        WIFI=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk -F: '/^\*/{print $2; exit}')
      else
        WIFI="wired"
      fi

      read -r GW_LOSS GW_RTT < <(ping_stats "$GATEWAY") || true
      read -r IN_LOSS IN_RTT < <(ping_stats "$ANCHOR") || true

      num_or_null() { [ -n "''${1:-}" ] && printf '%s' "$1" || printf 'null'; }
      if [ "''${WIFI:-}" = "wired" ]; then
        WIFI_JSON='"wired"'
      elif [ -n "''${WIFI:-}" ]; then
        WIFI_JSON=$(num_or_null "$WIFI")
      else
        WIFI_JSON='null'
      fi

      mkdir -p "$(dirname "$LOGFILE")"
      jq -nc \
        --arg     ts       "$(date -Iseconds)" \
        --argjson gw_loss  "$(num_or_null "$GW_LOSS")" \
        --argjson gw_rtt   "$(num_or_null "$GW_RTT")" \
        --argjson in_loss  "$(num_or_null "$IN_LOSS")" \
        --argjson in_rtt   "$(num_or_null "$IN_RTT")" \
        --argjson dns      "$(num_or_null "$DNS_MS")" \
        --arg     iface    "$RIFACE" \
        --argjson wifi     "$WIFI_JSON" \
        '{ts:$ts, gw_loss_pct:$gw_loss, gw_rtt_ms:$gw_rtt,
          inet_loss_pct:$in_loss, inet_rtt_ms:$in_rtt, dns_ms:$dns,
          route_iface:$iface, wifi_signal:$wifi}' \
        >> "$LOGFILE"
    '';
  };
in {
  options.services.netmon = {
    enable = lib.mkEnableOption "home-network health sampler (laptop-safe)";

    homeGateway = lib.mkOption {
      type = lib.types.str;
      default = "192.168.86.1";
      description = "Default-gateway IP that identifies the home network. Sampling only runs when the active default gateway matches this. On any other network the sampler exits silently.";
    };

    anchor = lib.mkOption {
      type = lib.types.str;
      default = "1.1.1.1";
      description = "Public IP pinged to gauge WAN/ISP health (no DNS needed).";
    };

    dnsName = lib.mkOption {
      type = lib.types.str;
      default = "cloudflare.com";
      description = "Domain resolved to time DNS lookups.";
    };

    logFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/log/netmon/netmon.jsonl";
      description = "JSON Lines output file; one sample object appended per run.";
    };

    pingCount = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Number of pings per target per sample.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "minutely";
      description = "systemd OnCalendar expression controlling sample frequency.";
    };

    onlyOnAC = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, only sample while on AC power (skips battery runs entirely, a proxy for 'at a desk'). The home-gateway guard already prevents coffee-shop runs; enable this only to also skip battery use at home.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.netmon = {
      description = "Home-network health sample";
      # Needs the network stack up to read routes; not a hard dependency.
      after = ["network.target"];
      serviceConfig =
        {
          Type = "oneshot";
          ExecStart = lib.getExe netmon;
          # Hardening: this only needs to read the network and write one log dir.
          LogsDirectory = "netmon";
          DynamicUser = false; # needs raw ICMP (ping) + /var/log write
          Nice = 10;
        }
        // lib.optionalAttrs cfg.onlyOnAC {
          ConditionACPower = true;
        };
    };

    systemd.timers.netmon = {
      description = "Run home-network health sample on a schedule";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = false; # don't backfill missed runs after suspend/away
        RandomizedDelaySec = 5;
      };
    };
  };
}
