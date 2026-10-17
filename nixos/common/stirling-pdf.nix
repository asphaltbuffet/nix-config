# nixos/common/stirling-pdf.nix
#
# Stirling-PDF as a Tailnet service (CONTEXT.md; ADR-0020): app container joined
# to its Tailnet sidecar (tailnet-services.nix), reachable only on tailnet :443.
# Tailnet side (tag:stirling, member -> 443 grant, tests) lives in
# tailscale/policy.hujson; runbook is docs/references/stirling-pdf-sop.md.
#
# Secret: secrets/stirling-env.age holds TS_AUTHKEY (OAuth client for tag:stirling).
_: let
  baseline = import ./container-baseline.nix;
in {
  imports = [./tailnet-services.nix];

  tailnetServices.stirling = {
    hostname = "stirling-pdf";
    uid = 61002;
    authKeyFile = ../../secrets/stirling-env.age;
    apps = ["stirling-pdf"];
  };

  virtualisation.oci-containers.containers.stirling-pdf = {
    image = "stirlingtools/stirling-pdf:3.2.0@sha256:10164ffe04961b02ebc9fa4da12064eeacb8d3bc3e09ceb059f78ce7aaa83207";
    environment.SECURITY_ENABLELOGIN = "false";
    # Shares the sidecar's namespace (the module adds --network and dependsOn):
    # 127.0.0.1:8080 here is where Serve proxies. No ports are published on the
    # host.
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
}
