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
{config, ...}: let
  baseline = import ./container-baseline.nix;

  # Containers that join micasa-egress / micasa-db, ordered after the unit that
  # creates them.
  networked = map (c: "docker-${c}.service") ["micasa-postgres"];
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

  virtualisation.oci-containers = {
    backend = "docker";
    containers.micasa-postgres = {
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
  };
}
