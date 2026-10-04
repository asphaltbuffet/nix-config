# nixos/common/wherefolk.nix
#
# Runs wherefolk (app + Tailscale sidecar) with the compose file shipped in the
# wherefolk repo, pinned by flake.lock. The tailnet side (tag:wherefolk, the
# 443-only grant) lives in tailscale/policy.hujson; the operator runbook is
# docs/operations/deployment.md in the wherefolk repo.
#
# Secret: secrets/wherefolk-env.age holds TS_AUTHKEY, WHEREFOLK_FULL_PASSPHRASE
# and WHEREFOLK_VERSION (see deploy/.env.example upstream).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  composeFile = "${inputs.wherefolk}/deploy/compose.yaml";
  envFile = config.age.secrets.wherefolk-env.path;
  compose = "${lib.getExe pkgs.docker-compose} -f ${composeFile} --env-file ${envFile}";
in {
  age.secrets.wherefolk-env = {
    file = ../../secrets/wherefolk-env.age;
    mode = "0400";
  };

  systemd.services.wherefolk = {
    description = "wherefolk (app + Tailscale sidecar)";
    wantedBy = ["multi-user.target"];
    after = ["docker.service" "network-online.target"];
    requires = ["docker.service"];
    wants = ["network-online.target"];
    # A flake bump changes the compose store path and restarts the stack.
    restartTriggers = [inputs.wherefolk];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # A failed pull (registry down) must not stop an already-pulled stack.
      ExecStartPre = "-${compose} pull";
      ExecStart = "${compose} up -d";
      # `stop`, never `down -v`: -v deletes the Directory (deployment.md §4).
      ExecStop = "${compose} stop";
      TimeoutStartSec = "300";
    };
  };
}
