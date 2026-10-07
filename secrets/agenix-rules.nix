let
  # ── Host SSH public keys (system secrets) ─────────────────────────────
  wendigo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDyrkGOX0lDcdIO5ehmjTzRhW9UEJwXRnFYAYbsFHz76";
  kushtaka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVXEd5gyLbgYnmmi9yrGL8zQcU2v8iXioIlSsCzZ57";
  snallygaster = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFe7wihS5yWkQCZhkJI2YNFj+p6M1wLos+s+GBaCNTJG";
  bunyip = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILgMwoEXAp/dvXtN+jehEy7ZdbwP1idOPLjvlFbNhb1J";
  arcade = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNATQe0rKnGoCJAH2dRqX3c/YnbQqqTinuhYX5tf5cD";
  allHosts = [wendigo kushtaka snallygaster bunyip arcade];

  # ── User SSH public keys (user secrets) ────────────────────────────────
  grue = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBCNN0FY6PqVhfejv10JDfq56G1DTR4RWNjPpt/LSNRN ben";
in {
  # ── System secrets ──────────────────────────────────────────────────────
  # thegamesdb.net scraper API key. Only the cabinet needs it; encrypted to
  # `grue` too so it can be edited without the cabinet's host key.
  "arcade/thegamesdbKey.age".publicKeys = [grue arcade];
  "grafanaKey.age".publicKeys = allHosts;
  # Shared token between Grafana and grafana-image-renderer, as an env file
  # (AUTH_TOKEN= for the renderer, GF_RENDERING_RENDERER_TOKEN= for Grafana).
  # Only bunyip runs them; `grue` can edit it.
  "grafanaRendererToken.age".publicKeys = [grue bunyip];

  # Tailscale API exporter env (TAILSCALE_TAILNET, TAILSCALE_OAUTH_CLIENT_ID,
  # TAILSCALE_OAUTH_CLIENT_SECRET): a read-only OAuth client, ADR-0023. Only bunyip runs it.
  "tailscale-exporter-env.age".publicKeys = [grue bunyip];

  # wherefolk container env (TS_AUTHKEY, passphrase, version). Only bunyip runs it.
  "wherefolk-env.age".publicKeys = [grue bunyip];

  # Stirling-PDF Tailscale sidecar env (TS_AUTHKEY, OAuth client for tag:stirling). Only bunyip runs it.
  "stirling-env.age".publicKeys = [grue bunyip];

  # micasa relay (ADR-0021): one env file per container, only bunyip runs them.
  # The Postgres password appears in both db-env and relay-env (DATABASE_URL).
  "micasa-ts-env.age".publicKeys = [grue bunyip];
  "micasa-db-env.age".publicKeys = [grue bunyip];
  "micasa-relay-env.age".publicKeys = [grue bunyip];

  # restic repository passwords (ADR-0022): one per repo, readable only by the
  # owning host and the admin. A recovery copy lives in 1Password.
  "restic-wendigo.age".publicKeys = [grue wendigo];
  "restic-kushtaka.age".publicKeys = [grue kushtaka];
  "restic-snallygaster.age".publicKeys = [grue snallygaster];
  "restic-bunyip.age".publicKeys = [grue bunyip];
  "restic-bunyip-srv.age".publicKeys = [grue bunyip];

  # NUT upsd password for upsmon / self-test / beeper (bunyip-only, nothing
  # else is a NUT client). Regenerable: no 1Password copy.
  "nut-upsmon.age".publicKeys = [grue bunyip];

  # ── User secrets: grue ──────────────────────────────────────────────────
  "grue/goreleaser.age".publicKeys = [grue] ++ allHosts;
  "grue/context7.age".publicKeys = [grue] ++ allHosts;
  "grue/github.age".publicKeys = [grue] ++ allHosts;
  "grue/githubMcp.age".publicKeys = [grue] ++ allHosts;
  "grue/protonmailUsername.age".publicKeys = [grue] ++ allHosts;
  "grue/protonmailPassword.age".publicKeys = [grue] ++ allHosts;
  "grue/resend.age".publicKeys = [grue] ++ allHosts;
}
