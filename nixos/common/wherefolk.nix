# nixos/common/wherefolk.nix
#
# wherefolk as a Tailnet service (CONTEXT.md; ADR-0020, ADR-0024): app container
# joined to its Tailnet sidecar (tailnet-services.nix). Migrated off upstream's
# deploy/compose.yaml. Tailnet side (tag:wherefolk, the 443-only grant for
# group:wherefolk-users) lives in tailscale/policy.hujson; runbook is
# docs/references/wherefolk-sop.md.
#
# Secrets, one per container: wherefolk-ts-env (TS_AUTHKEY), wherefolk-app-env
# (WHEREFOLK_FULL_PASSPHRASE; empty leaves the Full tier unavailable).
{config, ...}: let
  baseline = import ./container-baseline.nix;
in {
  imports = [./tailnet-services.nix];

  tailnetServices.wherefolk = {
    uid = 61003;
    authKeyFile = ../../secrets/wherefolk-ts-env.age;
    apps = ["wherefolk"];
  };

  age.secrets.wherefolk-app-env = {
    file = ../../secrets/wherefolk-app-env.age;
    mode = "0400";
  };

  # The Directory lives on the data disk so the Data-disk backup covers it
  # (ADR-0024). Owned by the image's nonroot user; the app refuses to start
  # without directory.json, which the cutover copies in (wherefolk-sop.md).
  systemd.tmpfiles.rules = ["d /srv/wherefolk 0700 65532 65532 -"];

  virtualisation.oci-containers.containers.wherefolk = {
    image = "ghcr.io/asphaltbuffet/wherefolk:0.1.0@sha256:54122626b9271cef70c964cd883bad22f84741c588f1f4783cc10f3235556d8b";
    environmentFiles = [config.age.secrets.wherefolk-app-env.path];
    # Fixed: the module's serve.json proxies to this port (tailnetServices.port).
    environment.WHEREFOLK_PORT = "8080";
    volumes = ["/srv/wherefolk:/var/lib/wherefolk"];
    # Full baseline: the image already runs as nonroot (65532) and writes only
    # the Directory volume.
    extraOptions =
      baseline
      ++ [
        "--user=65532:65532"
        "--read-only"
        "--tmpfs=/tmp:rw,size=64m"
        "--memory=512m"
        "--cpus=1"
        "--pids-limit=256"
      ];
  };
}
