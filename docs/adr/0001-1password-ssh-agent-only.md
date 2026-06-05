# 1Password used as SSH agent only, not as secrets backend

1Password manages interactive SSH authentication and commit signing (git/jj) for the primary user. All other secrets (API keys, system credentials) remain in agenix. This is a deliberate split — 1Password is not a replacement for agenix.

Headless systems and remote SSH sessions cannot use the 1Password desktop agent: the agent requires an unlocked desktop app on the local machine. Replacing agenix with 1Password service accounts was evaluated and rejected because it trades one on-disk secret (age key) for another (service account token) and adds a hard network dependency on the 1Password API at every boot. The `op inject` pattern for user-session secrets was also evaluated but is insufficient for system-level secrets that must be available before any user logs in.

## Considered options

- **Full 1Password** (opnix / service account token) — rejected: on-disk token, boot-time network dependency, no fallback if API unreachable; breaks headless hosts
- **agenix only** — rejected: no biometric-gated SSH auth or commit signing; private key material would need to exist as a file
- **1Password for agent + agenix for secrets** — chosen: each tool does what it is suited for
