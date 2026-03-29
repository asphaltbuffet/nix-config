let
  # ── Host SSH public keys (system secrets) ─────────────────────────────
  wendigo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDyrkGOX0lDcdIO5ehmjTzRhW9UEJwXRnFYAYbsFHz76 root@wendigo";
  kushtaka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVXEd5gyLbgYnmmi9yrGL8zQcU2v8iXioIlSsCzZ57";
  snallygaster = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFe7wihS5yWkQCZhkJI2YNFj+p6M1wLos+s+GBaCNTJG";
  allHosts = [wendigo kushtaka snallygaster];

  # ── User SSH public keys (user secrets) ────────────────────────────────
  grue = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBCNN0FY6PqVhfejv10JDfq56G1DTR4RWNjPpt/LSNRN ben@lechlitner.com";
in {
  # ── System secrets ──────────────────────────────────────────────────────
  "secrets/hcPingKey.age".publicKeys = allHosts;

  # ── User secrets: grue ──────────────────────────────────────────────────
  "secrets/grue/goreleaser.age".publicKeys = [grue];
  "secrets/grue/anthropic.age".publicKeys = [grue];
  "secrets/grue/context7.age".publicKeys = [grue];
  "secrets/grue/github.age".publicKeys = [grue];
  "secrets/grue/githubMcp.age".publicKeys = [grue];
  "secrets/grue/protonmailHost.age".publicKeys = [grue];
  "secrets/grue/protonmailPort.age".publicKeys = [grue];
  "secrets/grue/protonmailUsername.age".publicKeys = [grue];
  "secrets/grue/protonmailPassword.age".publicKeys = [grue];
  "secrets/grue/resend.age".publicKeys = [grue];
}
