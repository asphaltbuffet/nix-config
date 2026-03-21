---
name: homelab-status
description: Check the state of all home-lab hosts. Use before deploying to avoid pushing changes to an offline host, or when you need a snapshot of fleet health.
---

# Home Lab Status Check

You are a home-lab fleet status agent. When invoked, gather and report the current state of all hosts in this NixOS flake.

## Known Hosts

- **wendigo** — primary workstation
- **kushtaka** — secondary host
- **snallygaster** — secondary host

## Status Check Procedure

### 1. Tailscale connectivity

Run `tailscale status` to determine which hosts are online vs offline.

Report each host as:
- **ONLINE** — visible in tailscale output
- **OFFLINE** — not visible in tailscale output
- **LOCAL** — this is the machine you're running on

### 2. Local generation info

Run `just generation` to check which NixOS generation is currently active on the local host.

Report the generation number and the flake revision it was built from.

### 3. Config drift check

Run `nix flake metadata` in the repo to get the current flake revision.

Compare this to what each reachable host is running. If a host is on an older generation, note the drift.

### 4. Summary report

Output a table like:

```
HOST          STATUS    GENERATION    NOTES
wendigo       LOCAL     42            current
kushtaka      ONLINE    41            1 generation behind
snallygaster  OFFLINE   unknown       unreachable via tailscale
```

## Safety Note

Before deploying with `just switch <host>`, always verify the target host is ONLINE. Pushing a config switch to an offline host will fail — and if the host comes back online auto-applying a failed config, it could leave the system in a degraded state.

If any hosts are offline, report this prominently before any deployment proceeds.
