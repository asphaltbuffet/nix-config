# nixos/common/micasa.nix
#
# micasa sync relay as a Tailnet service (CONTEXT.md; ADR-0020, ADR-0021):
# Tailscale sidecar + relay (sharing the sidecar's namespace) + Postgres on an
# internal Docker network the sidecar also joins, so Postgres is never on the
# tailnet node. Tailnet side (tag:micasa, member -> 443, tests) lives in
# tailscale/policy.hujson; runbook is docs/references/micasa-sop.md.
#
# Secrets, one per container: micasa-ts-env (TS_AUTHKEY), micasa-db-env
# (POSTGRES_PASSWORD), micasa-relay-env (DATABASE_URL, RELAY_ENCRYPTION_KEY).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  baseline = import ./container-baseline.nix;

  # Containers that join micasa-egress / micasa-db, ordered after the unit that
  # creates them.
  networked = map (c: "docker-${c}.service") ["micasa-ts" "micasa-postgres"];

  # Upstream publishes no relay image and packages only cmd/micasa, so the
  # relay is built from the same input as the TUI (ADR-0021).
  relay = inputs.micasa.packages.${pkgs.stdenv.hostPlatform.system}.micasa.overrideAttrs (old: {
    pname = "micasa-relay";
    subPackages = ["cmd/relay"];
    tags = ["selfhosted"];
    meta = old.meta // {mainProgram = "relay";};
  });

  # Static binary, nothing else. The tag defaults to the content hash, so a new
  # binary is a new image string and systemd restarts the unit.
  relayImage = pkgs.dockerTools.streamLayeredImage {
    name = "micasa-relay";
    config = {
      Entrypoint = [(lib.getExe relay)];
      User = "65534:65534";
    };
  };

  # ${TS_CERT_DOMAIN} is expanded by containerboot, not Nix, hence the escapes.
  serveConfig = pkgs.writeText "micasa-serve.json" (builtins.toJSON {
    TCP."443".HTTPS = true;
    Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://127.0.0.1:8080";
    AllowFunnel."\${TS_CERT_DOMAIN}:443" = false;
  });
in {
  age.secrets = {
    micasa-ts-env = {
      file = ../../secrets/micasa-ts-env.age;
      mode = "0400";
    };
    micasa-db-env = {
      file = ../../secrets/micasa-db-env.age;
      mode = "0400";
    };
    micasa-relay-env = {
      file = ../../secrets/micasa-relay-env.age;
      mode = "0400";
    };
  };

  # Docker cannot combine the default bridge with a user-defined network, so
  # the sidecar's egress is a user-defined network too. micasa-db is
  # --internal: no route out.
  systemd.services.docker-network-micasa = {
    description = "Docker networks for the micasa relay";
    after = ["docker.service"];
    requires = ["docker.service"];
    before = networked;
    requiredBy = networked;
    path = [config.virtualisation.docker.package];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker network inspect micasa-egress >/dev/null 2>&1 || docker network create micasa-egress
      docker network inspect micasa-db >/dev/null 2>&1 || docker network create --internal micasa-db
    '';
  };

  # Non-root sidecar needs a state dir it owns: a fresh named volume is
  # root-owned and tailscaled cannot chmod it (it falls back to an in-memory
  # store, i.e. a new node each restart).
  systemd.tmpfiles.rules = ["d /var/lib/micasa-ts 0700 61001 61001 -"];

  # Postgres refuses TCP while initdb runs on first boot; the relay exits and is
  # restarted. Without a delay, systemd's default start limit (5 in 10 s) can
  # trip and leave it failed.
  systemd.services.docker-micasa-relay.serviceConfig.RestartSec = "5s";

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      micasa-postgres = {
        image = "postgres:17.11-alpine@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24";
        environmentFiles = [config.age.secrets.micasa-db-env.path];
        environment = {
          POSTGRES_USER = "micasa";
          POSTGRES_DB = "micasa";
        };
        volumes = ["micasa-pgdata:/var/lib/postgresql/data"];
        networks = ["micasa-db"];
        # Full baseline: as uid 70 (alpine's postgres) from the start the
        # entrypoint needs no chown/setuid; a fresh named volume inherits the
        # image's postgres-owned data dir.
        extraOptions =
          baseline
          ++ [
            "--user=70:70"
            "--read-only"
            "--tmpfs=/var/run/postgresql:rw,size=16m"
            "--tmpfs=/tmp:rw,size=64m"
            "--memory=512m"
            "--cpus=1"
            "--pids-limit=256"
          ];
      };

      micasa-ts = {
        image = "tailscale/tailscale:v1.102.5@sha256:c507f3a2a6ab1cabd8d809b98edeb41edbd5c3fb6ad9632ffd098b4c7d0b4065";
        environmentFiles = [config.age.secrets.micasa-ts-env.path];
        environment = {
          TS_HOSTNAME = "micasa";
          # OAuth clients can only mint tagged nodes.
          TS_EXTRA_ARGS = "--advertise-tags=tag:micasa";
          # Without persisted state every restart authenticates as a new node.
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_SERVE_CONFIG = "/config/serve.json";
          # No tun device and no NET_ADMIN: the sidecar needs neither to serve.
          TS_USERSPACE = "true";
        };
        volumes = [
          "/var/lib/micasa-ts:/var/lib/tailscale"
          "${serveConfig}:/config/serve.json:ro"
        ];
        # Egress for the control plane; micasa-db so the relay, which shares
        # this namespace, can reach micasa-postgres.
        networks = ["micasa-egress" "micasa-db"];
        extraOptions =
          baseline
          ++ [
            "--user=61001:61001"
            "--read-only"
            "--tmpfs=/tmp:rw,size=16m"
            "--tmpfs=/var/run:rw,size=16m"
            "--memory=256m"
            "--cpus=0.5"
            "--pids-limit=256"
          ];
      };

      micasa-relay = {
        image = "micasa-relay:${relayImage.imageTag}";
        imageStream = relayImage;
        # Requires= on both: an explicit restart of the sidecar restarts the
        # relay so it rejoins the fresh namespace. A crash-restart of the sidecar
        # does not, leaving the relay in a dead namespace (Serve returns 502);
        # see the SOP. Postgres may still be initialising on first boot; the
        # relay exits and systemd restarts it until it connects.
        dependsOn = ["micasa-ts" "micasa-postgres"];
        environmentFiles = [config.age.secrets.micasa-relay-env.path];
        # BLOB_QUOTA deliberately unset (unlimited, ADR-0021).
        environment = {
          PORT = "8080";
          SELF_HOSTED = "true";
        };
        extraOptions =
          baseline
          ++ [
            "--network=container:micasa-ts"
            "--user=65534:65534"
            "--read-only"
            "--tmpfs=/tmp:rw,size=128m"
            "--memory=256m"
            "--cpus=1"
            "--pids-limit=256"
          ];
      };
    };
  };
}
