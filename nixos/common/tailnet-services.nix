# nixos/common/tailnet-services.nix
#
# Tailnet services (CONTEXT.md; ADR-0020, ADR-0024): one Tailscale sidecar per
# service, declared as tailnetServices.<key>. The key is the identity: it names
# the sidecar container (<key>-ts), its state dir (/var/lib/<key>-ts), its
# policy tag (tag:<key>) and its agenix secret (<key>-ts-env). Renaming the
# device is `hostname`, which never moves the state dir.
#
# The module joins the named app containers to the sidecar's namespace; their
# image, user, capabilities and limits stay in the service's own module, where
# ADR-0020 wants any baseline exception justified. The tailnet side (tag owners,
# grants, tests) is tailscale/policy.hujson, pasted by hand (ADR-0019).
#
# Import from each service module: imports = [./tailnet-services.nix];
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.tailnetServices;
  baseline = import ./container-baseline.nix;
  containers = config.virtualisation.oci-containers.containers;

  sidecar = key: "${key}-ts";
  dupes = xs: lib.unique (lib.filter (x: lib.count (y: y == x) xs > 1) xs);
  uids = lib.mapAttrsToList (_: s: s.uid) cfg;
  hostnames = lib.mapAttrsToList (_: s: s.hostname) cfg;

  # ${TS_CERT_DOMAIN} is expanded by containerboot, not Nix, hence the escapes.
  serveConfig = s:
    pkgs.writeText "${s.hostname}-serve.json" (builtins.toJSON {
      TCP."443".HTTPS = true;
      Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://127.0.0.1:${toString s.port}";
      AllowFunnel."\${TS_CERT_DOMAIN}:443" = false;
    });

  sidecarContainer = key: s: let
    uid = toString s.uid;
  in {
    image = "tailscale/tailscale:v1.102.5@sha256:c507f3a2a6ab1cabd8d809b98edeb41edbd5c3fb6ad9632ffd098b4c7d0b4065";
    environmentFiles = [config.age.secrets."${key}-ts-env".path];
    environment = {
      TS_HOSTNAME = s.hostname;
      # OAuth clients can only mint tagged nodes.
      TS_EXTRA_ARGS = "--advertise-tags=tag:${key}";
      # Without persisted state every restart authenticates as a new node.
      TS_STATE_DIR = "/var/lib/tailscale";
      TS_SERVE_CONFIG = "/config/serve.json";
      # No tun device and no NET_ADMIN: the sidecar needs neither to serve.
      TS_USERSPACE = "true";
    };
    volumes = [
      "/var/lib/${key}-ts:/var/lib/tailscale"
      "${serveConfig s}:/config/serve.json:ro"
    ];
    inherit (s) networks;
    # Meets the full baseline: non-root, read-only, no capabilities.
    extraOptions =
      baseline
      ++ [
        "--user=${uid}:${uid}"
        "--read-only"
        "--tmpfs=/tmp:rw,size=16m"
        "--tmpfs=/var/run:rw,size=16m"
        "--memory=256m"
        "--cpus=0.5"
        "--pids-limit=256"
      ];
  };

  # dependsOn makes systemd Requires=: restarting the sidecar restarts the app
  # too, so it rejoins the sidecar's fresh network namespace.
  joinedApp = key: {
    dependsOn = [(sidecar key)];
    extraOptions = ["--network=container:${sidecar key}"];
  };
in {
  options.tailnetServices = mkOption {
    default = {};
    description = "Tailnet services on this host, keyed by service identity (ADR-0024).";
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        hostname = mkOption {
          type = types.str;
          default = name;
          description = "Tailnet device name (TS_HOSTNAME); registered in host.tailnetSidecars for the tailnet dashboard.";
        };
        uid = mkOption {
          type = types.ints.between 1000 65535;
          description = "Static uid:gid the sidecar runs as and that owns /var/lib/<key>-ts. Unique per host.";
        };
        authKeyFile = mkOption {
          type = types.path;
          description = "agenix .age file holding TS_AUTHKEY (an OAuth client for tag:<key>).";
        };
        apps = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "oci-containers names to join to the sidecar's network namespace.";
        };
        networks = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Extra Docker networks the sidecar (and so its apps) joins.";
        };
        port = mkOption {
          type = types.port;
          default = 8080;
          description = "Loopback port the app listens on; Serve proxies tailnet :443 to it.";
        };
      };
    }));
  };

  config = lib.mkIf (cfg != {}) {
    assertions =
      [
        {
          assertion = dupes uids == [];
          message = "tailnetServices: sidecar uids must be unique; duplicated: ${lib.concatMapStringsSep ", " toString (dupes uids)}";
        }
        {
          assertion = dupes hostnames == [];
          message = "tailnetServices: hostnames must be unique; duplicated: ${lib.concatStringsSep ", " (dupes hostnames)}";
        }
      ]
      ++ lib.concatLists (lib.mapAttrsToList (key: s:
        map (app: {
          assertion = lib.length (lib.filter (lib.hasPrefix "--network") containers.${app}.extraOptions) == 1;
          message = "tailnetServices.${key}: app ${app} sets its own --network; the module joins it to ${sidecar key}.";
        })
        s.apps)
      cfg);

    host.tailnetSidecars = hostnames;

    age.secrets = lib.mapAttrs' (key: s:
      lib.nameValuePair "${key}-ts-env" {
        file = s.authKeyFile;
        mode = "0400";
      })
    cfg;

    # Non-root sidecar needs a state dir it owns: a fresh named volume is
    # root-owned and tailscaled cannot chmod it (it falls back to an in-memory
    # store, i.e. a new node each restart).
    systemd.tmpfiles.rules = lib.mapAttrsToList (key: s: "d /var/lib/${key}-ts 0700 ${toString s.uid} ${toString s.uid} -") cfg;

    virtualisation.oci-containers = {
      backend = "docker";
      containers = lib.mkMerge (lib.mapAttrsToList (key: s:
        {${sidecar key} = sidecarContainer key s;}
        // lib.genAttrs s.apps (_: joinedApp key))
      cfg);
    };
  };
}
