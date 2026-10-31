# nixos/common/wherehouse.nix
#
# wherehouse as a Tailnet service (CONTEXT.md; ADR-0020, ADR-0024): app container
# joined to its Tailnet sidecar (tailnet-services.nix). Tailnet side
# (tag:wherehouse, the 443-only grant for autogroup:member) lives in
# tailscale/policy.hujson.
#
# Secret: wherehouse-ts-env (TS_AUTHKEY). The app has no secrets and no auth:
# the tailnet grant is the only access control. Identity (for the event log
# only) comes from Serve's header.
let
  baseline = import ./container-baseline.nix;
in {
  imports = [./tailnet-services.nix];

  tailnetServices.wherehouse = {
    uid = 61005;
    authKeyFile = ../../secrets/wherehouse-ts-env.age;
    apps = ["wherehouse"];
  };

  # The database lives on the data disk so the Data-disk backup covers it.
  # 65533, not the image's 65532: wherefolk's app already runs as 65532 and owns
  # /srv/wherefolk, and a container escape from one must not reach the other's data.
  systemd.tmpfiles.rules = ["d /srv/wherehouse 0700 65533 65533 -"];

  # /srv is nofail: without this a slow or dead data disk leaves an empty
  # /srv/wherehouse on the root fs, and the app starts a fresh database there.
  systemd.services.docker-wherehouse.unitConfig.RequiresMountsFor = ["/srv/wherehouse"];

  virtualisation.oci-containers.containers.wherehouse = {
    image = "ghcr.io/asphaltbuffet/wherehouse:0.10.2@sha256:e8b66e5063f91b9aa8273261e8ef86897ce3aea75c5b19d7c76205b9106d32ec";
    # The entrypoint binds 0.0.0.0, which in the sidecar's namespace includes its
    # default-bridge address: other containers could reach :8080 around Serve.
    # Loopback only, so Serve is the sole path in. The last --bind wins.
    # That makes Serve's Tailscale-User-Login header trustworthy, so it is
    # recorded as the event actor (asphaltbuffet/wherehouse#267); requests
    # without it (tagged nodes) fall back to "webui".
    cmd = ["--bind" "127.0.0.1" "--actor-header" "Tailscale-User-Login"];
    volumes = ["/srv/wherehouse:/data"];
    # Full baseline: distroless static, writes only the database volume.
    extraOptions =
      baseline
      ++ [
        "--user=65533:65533"
        "--read-only"
        "--tmpfs=/tmp:rw,size=64m"
        "--memory=256m"
        "--cpus=0.5"
        "--pids-limit=256"
      ];
  };
}
