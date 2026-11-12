# nixos/common/atuin.nix
#
# atuin sync server as a Tailnet service (CONTEXT.md; ADR-0020, ADR-0021,
# ADR-0025): Tailscale sidecar (tailnet-services.nix) + upstream atuin-server
# (sharing the sidecar's namespace) + Postgres on an internal Docker network the
# sidecar also joins, so Postgres is never on the tailnet node. Tailnet side
# (tag:atuin, member -> 443, tests) lives in tailscale/policy.hujson.
#
# Secrets, one per container: atuin-ts-env (TS_AUTHKEY), atuin-db-env
# (POSTGRES_PASSWORD), atuin-server-env (ATUIN_DB_URI).
{config, ...}: let
  baseline = import ./container-baseline.nix;

  # Containers that join atuin-egress / atuin-db, ordered after the unit that
  # creates them.
  networked = map (c: "docker-${c}.service") ["atuin-ts" "atuin-postgres"];
in {
  imports = [./tailnet-services.nix];

  tailnetServices.atuin = {
    uid = 61004;
    authKeyFile = ../../secrets/atuin-ts-env.age;
    apps = ["atuin-server"];
    port = 8888;
    # Egress for the control plane; atuin-db so the server, which shares the
    # sidecar's namespace, can reach atuin-postgres.
    networks = ["atuin-egress" "atuin-db"];
  };

  age.secrets = {
    atuin-db-env = {
      file = ../../secrets/atuin-db-env.age;
      mode = "0400";
    };
    atuin-server-env = {
      file = ../../secrets/atuin-server-env.age;
      mode = "0400";
    };
  };

  # Docker cannot combine the default bridge with a user-defined network, so
  # the sidecar's egress is a user-defined network too. atuin-db is
  # --internal: no route out.
  systemd = {
    services.docker-network-atuin = {
      description = "Docker networks for the atuin sync server";
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
        docker network inspect atuin-egress >/dev/null 2>&1 || docker network create atuin-egress
        docker network inspect atuin-db >/dev/null 2>&1 || docker network create --internal atuin-db
      '';
    };

    # Postgres refuses TCP while initdb runs on first boot; the server exits and
    # is restarted. Without a delay, systemd's default start limit (5 in 10 s)
    # can trip and leave it failed.
    services.docker-atuin-server.serviceConfig.RestartSec = "5s";
  };

  virtualisation.oci-containers.containers = {
    atuin-postgres = {
      image = "postgres:17.11-alpine@sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0";
      environmentFiles = [config.age.secrets.atuin-db-env.path];
      environment = {
        POSTGRES_USER = "atuin";
        POSTGRES_DB = "atuin";
      };
      # No backup: the server holds only ciphertext; devices are the backup
      # (ADR-0021, ADR-0025).
      volumes = ["atuin-pgdata:/var/lib/postgresql/data"];
      networks = ["atuin-db"];
      # Full baseline, as micasa-postgres.
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

    atuin-server = {
      image = "ghcr.io/atuinsh/atuin:18.24.7@sha256:2a77d9c015f9907f3602305c5c5ddc71bc96a37c453aa6338ea6745474233418";
      # The image's entrypoint is atuin-server with no Cmd; without a
      # subcommand clap exits 2 and the unit restarts forever.
      cmd = ["start"];
      # Requires=: Postgres may still be initialising on first boot; the server
      # exits and systemd restarts it until it connects. (The module adds
      # atuin-ts, and the --network that joins its namespace.)
      dependsOn = ["atuin-postgres"];
      environmentFiles = [config.age.secrets.atuin-server-env.path];
      environment = {
        # Loopback of the sidecar's namespace; Serve proxies :443 to it.
        ATUIN_HOST = "127.0.0.1";
        ATUIN_PORT = "8888";
        # Any tailnet member may register (ADR-0025).
        ATUIN_OPEN_REGISTRATION = "true";
      };
      # Full baseline. The server writes a default server.toml into
      # ATUIN_CONFIG_DIR (/config) when it is missing, hence the tmpfs there.
      # Keep it a tmpfs: a server.toml overrides these ATUIN_* env vars.
      extraOptions =
        baseline
        ++ [
          "--user=1000:1000"
          "--read-only"
          "--tmpfs=/config:rw,size=1m,uid=1000,gid=1000,mode=0700"
          "--tmpfs=/tmp:rw,size=64m"
          "--memory=256m"
          "--cpus=1"
          "--pids-limit=256"
        ];
    };
  };
}
