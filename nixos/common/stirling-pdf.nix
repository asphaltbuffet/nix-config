# nixos/common/stirling-pdf.nix
#
# Stirling-PDF as a Tailnet service (CONTEXT.md; ADR-0020): app container +
# Tailscale sidecar, reachable only on tailnet :443. Tailnet side (tag:stirling,
# member -> 443 grant, tests) lives in tailscale/policy.hujson; runbook is
# docs/references/stirling-pdf-sop.md.
#
# Secret: secrets/stirling-env.age holds TS_AUTHKEY (OAuth client for tag:stirling).
{
  config,
  pkgs,
  ...
}: let
  baseline = import ./container-baseline.nix;

  # ${TS_CERT_DOMAIN} is expanded by containerboot, not Nix, hence the escapes.
  serveConfig = pkgs.writeText "stirling-pdf-serve.json" (builtins.toJSON {
    TCP."443".HTTPS = true;
    Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://127.0.0.1:8080";
    AllowFunnel."\${TS_CERT_DOMAIN}:443" = false;
  });
in {
  age.secrets.stirling-env = {
    file = ../../secrets/stirling-env.age;
    mode = "0400";
  };

  # Non-root sidecar needs a state dir it owns: a fresh named volume is
  # root-owned and tailscaled cannot chmod it (it falls back to an in-memory
  # store, i.e. a new node each restart).
  systemd.tmpfiles.rules = ["d /var/lib/stirling-ts 0700 61002 61002 -"];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      stirling-ts = {
        image = "tailscale/tailscale:v1.102.5@sha256:c507f3a2a6ab1cabd8d809b98edeb41edbd5c3fb6ad9632ffd098b4c7d0b4065";
        environmentFiles = [config.age.secrets.stirling-env.path];
        environment = {
          TS_HOSTNAME = "stirling-pdf";
          # OAuth clients can only mint tagged nodes.
          TS_EXTRA_ARGS = "--advertise-tags=tag:stirling";
          # Without persisted state every restart authenticates as a new node.
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_SERVE_CONFIG = "/config/serve.json";
          # No tun device and no NET_ADMIN: the sidecar needs neither to serve.
          TS_USERSPACE = "true";
        };
        volumes = [
          "/var/lib/stirling-ts:/var/lib/tailscale"
          "${serveConfig}:/config/serve.json:ro"
        ];
        # Meets the full baseline: non-root, read-only, no capabilities.
        extraOptions =
          baseline
          ++ [
            "--user=61002:61002"
            "--read-only"
            "--tmpfs=/tmp:rw,size=16m"
            "--tmpfs=/var/run:rw,size=16m"
            "--memory=256m"
            "--cpus=0.5"
            "--pids-limit=256"
          ];
      };

      stirling-pdf = {
        image = "stirlingtools/stirling-pdf:3.1.0@sha256:b5b9e400c086e5334a4947a0d7cd589808f743f29267d7f41c18200cf4bc48b4";
        # dependsOn makes systemd Requires=: restarting the sidecar restarts the
        # app too, so it rejoins the sidecar's fresh network namespace.
        dependsOn = ["stirling-ts"];
        environment.SECURITY_ENABLELOGIN = "false";
        # Shares the sidecar's namespace: 127.0.0.1:8080 here is where Serve
        # proxies. No ports are published on the host.
        #
        # Documented exceptions to the baseline (ADR-0020): no --user and no
        # --read-only. The entrypoint starts as root, creates users, edits
        # /etc/passwd and writes under /usr and /var/lib before dropping to uid
        # 1000 with setpriv; upstream supports neither flag. The root phase
        # needs SETUID/SETGID for setpriv, and CHOWN/DAC_OVERRIDE/FOWNER for the
        # chown -R / chmod -R it runs building the LibreOffice profile template
        # (scripts/init-without-ocr.sh). The app holds no capabilities once it
        # has dropped to uid 1000.
        extraOptions =
          baseline
          ++ [
            "--network=container:stirling-ts"
            "--cap-add=SETUID"
            "--cap-add=SETGID"
            "--cap-add=CHOWN"
            "--cap-add=DAC_OVERRIDE"
            "--cap-add=FOWNER"
            "--memory=4g"
            "--cpus=2"
            "--pids-limit=1024"
          ];
      };
    };
  };
}
