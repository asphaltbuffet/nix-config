# NixOS Automated Update Strategies: Research Report

**Date:** March 2026
**Audience:** NixOS system administrator (personal/family use cases)
**Scope:** Automated config pull from GitHub, build verification before activation, weekly `flake.lock` update with auto-commit back to repo

---

## Executive Summary

- The built-in `system.autoUpgrade` NixOS module creates a systemd timer that runs `nixos-rebuild switch --flake github:owner/repo#hostname` on a schedule — the lowest-complexity path to automated config-pull and activation, requiring no extra tooling [S1]. However, it has a known `--update-input` deprecation issue [S2] and provides no built-in build-verification gate before activation [S9].
- The community-validated recommendation for flake-based systems is to point `system.autoUpgrade.flake` to a **remote GitHub URI** (`github:owner/repo#hostname`) rather than `inputs.self.outPath`. The latter only rebuilds from what is already on disk and does not pull updates [S3].
- The most robust fully-automated pipeline combines **GitHub Actions** (updates `flake.lock` and commits it on a weekly schedule) with a **systemd pull-rebuild** on each machine. Multiple practitioners report this pattern working reliably in production [S5][S7].
- Build verification before activation is achievable using `nixos-rebuild build` as a non-destructive gate (non-zero exit on failure), followed conditionally by `nixos-rebuild switch`. This pattern is not built into `system.autoUpgrade` but can be implemented in a custom systemd service [S9][S18].
- Push-based deployment tools (`deploy-rs`, `colmena`) require an operator machine to initiate each deployment and are not suitable for autonomous unattended machines such as family member laptops [S12][S13].
- Security risk is meaningfully reduced when the flake URI points to `github:owner/repo` rather than a user-owned local directory, because trust is delegated to GitHub account security (2FA) rather than local file permissions — preventing a compromised user account from injecting malicious NixOS config that root will auto-apply [S8].

---

## Research Question and Scope

**Primary question:** What are the best methods to automate NixOS updates for systems not under active development — specifically (a) pulling the latest configuration from a GitHub repository, verifying a clean build, and applying it; and (b) updating `flake.lock` weekly and auto-committing it back to the repository?

**In scope:**
- NixOS flake-based systems managed from a personal GitHub repository
- Pull-based autonomous operation (no administrator present at update time)
- Single-user desktop and laptop use cases (family member machines)
- Desktop/GUI notification of pending reboots or failed updates
- Security considerations appropriate to a personal threat model

**Out of scope:**
- Zero-downtime rolling updates for production server clusters
- Channel-based (non-flake) NixOS systems
- CI/CD pipelines for software development
- Multi-datacenter fleet management

---

## Methodology

Evidence was gathered across 18 sources in four categories:

- **Official NixOS documentation:** wiki pages on `system.autoUpgrade` [S1] and `nixos-rebuild` [S9], the nixpkgs option reference [S15], and the upstream `auto-upgrade.nix` module source [S16].
- **Community discourse and issue trackers:** NixOS Discourse threads on auto-upgrade best practices [S3], security considerations [S8], desktop notifications [S14], and the nixpkgs GitHub issue tracking the `--update-input` deprecation [S2].
- **Practitioner blogs (2023–2025):** Working implementations from Forrest Jacobs [S4], Gaël Gothié [S5], Nelson Dane [S7], and framing analysis from aires.fyi [S17] and nixcademy.com [S18].
- **Third-party tools:** `DeterminateSystems/update-flake-lock` [S6], `nvd` [S10], `nixos-autodeploy` [S11], `deploy-rs` [S12], and `colmena` [S13].

Sources were weighted by recency (2024–2025 preferred), confirmed production status, and direct applicability to pull-based unattended personal machines.

---

## Key Findings

**1. Pointing `flake` at `inputs.self.outPath` does NOT pull updates from GitHub.**
Using `flake = inputs.self.outPath` in `system.autoUpgrade` rebuilds from the configuration already present on disk. To actually fetch new commits from GitHub, `flake` must be set to `"github:owner/repo#hostname"` [S1][S3]. This distinction is the single most common cause of confusion reported in community threads [S17].

**2. The `--update-input` flag used in many community examples is deprecated.**
Any configuration using `flags = ["--update-input" "nixpkgs"]` will break when Nix removes this flag. The correct replacement is managing `flake.lock` updates separately via `nix flake update`, not via `nixos-rebuild` flags [S2].

**3. The two-layer GitOps pipeline is the most widely validated approach.**
Multiple independent practitioners have converged on: GitHub Actions updates `flake.lock` at 03:00, systemd timers on each machine pull and rebuild at 04:00. One operator reports "no issues in 4 months" running household DHCP services with this pattern [S5]. A university cluster uses the same architecture across multiple nodes [S7].

**4. `nixos-rebuild build` enables non-destructive pre-switch verification.**
`nixos-rebuild build --flake github:owner/repo#hostname` fetches and builds the configuration without activating it, exiting non-zero on failure. This is the correct gate for "only switch if clean build" logic [S9][S18].

**5. `persistent = true` is essential for laptop use cases.**
Without `Persistent=true` on the systemd timer, a machine that is powered off during the scheduled window will not catch up on its next boot. `persistent = true` in the timer configuration ensures the upgrade runs after the next boot if it was missed [S1][S15].

**6. `nvd` provides human-readable package change summaries for notifications.**
`nvd diff /run/booted-system /run/current-system` produces a table of package additions, removals, and version changes. This output can be piped into email notifications to give the administrator a running log of what each automated update changed [S10].

**7. Desktop notifications from system services are non-trivial to implement correctly.**
`nixos-upgrade.service` runs in the system D-Bus context; `notify-send` targets the user session bus. The gap requires either `services.systembus-notify.enable = true`, `wall`, or email via `msmtp` — with email being the most reliable for remote administration of family machines [S14].

**8. Security risk of automated updates is real but manageable.**
A user-owned config repo combined with root-executed auto-upgrade creates a privilege escalation path if the user account is compromised. Pointing `flake` to a GitHub URI shifts the trust boundary to GitHub (mitigated by 2FA and branch protection) and eliminates local file permission issues entirely [S8].

**9. Push-based tools (deploy-rs, colmena) require an operator and are unsuitable for unattended autonomous updates.**
Both tools require an admin machine to initiate each deployment cycle. They are appropriate for managed fleet scenarios where an administrator is actively involved in each update, not for set-and-forget family laptops [S12][S13].

**10. A new polling-based tool (`nixos-autodeploy`) exists but has limited community adoption.**
Announced June 2025, `nixos-autodeploy` continuously polls the upstream flake, compares derivations, and auto-switches only on verified state match, with Prometheus metrics. Maturity and community validation are limited as of this writing [S11].

---

## Analysis

### Approach 1: `system.autoUpgrade` (Built-in NixOS Module)

The `system.autoUpgrade` module is the path of least resistance. It creates `nixos-upgrade.timer` and `nixos-upgrade.service` as standard systemd units, requiring no additional tooling. For flake systems, the critical setting is the `flake` option — it must be a GitHub URI, not `inputs.self.outPath` [S1][S3]:

```nix
system.autoUpgrade = {
  enable = true;
  flake = "github:owner/repo#hostname";
  flags = [ "--print-build-logs" ];
  operation = "switch";  # or "boot" for safer next-reboot-only activation
  dates = "04:00";
  randomizedDelaySec = "1h";
  persistent = true;
  allowReboot = false;           # set true + rebootWindow for automated kernel updates
  rebootWindow = { lower = "02:00"; upper = "06:00"; };
  runGarbageCollection = true;
};
```

**Key options:**

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `enable` | bool | false | Activates the timer/service |
| `flake` | string | "" | GitHub URI or local path for the flake |
| `flags` | list(string) | [] | Extra flags passed to `nixos-rebuild` |
| `operation` | enum | switch | `switch` (live) or `boot` (next reboot only) |
| `dates` | string | "04:40" | Systemd calendar expression |
| `randomizedDelaySec` | string | "" | Randomize start time (prevents cache stampede) |
| `persistent` | bool | false | Run after boot if missed while offline |
| `allowReboot` | bool | false | Auto-reboot for kernel updates |
| `rebootWindow` | {lower,upper} | — | Restrict auto-reboots to time window |
| `runGarbageCollection` | bool | false | Run `nix-gc` after successful upgrade |
| `fixedRandomDelay` | bool | false | Same random offset each run |

Monitor with: `systemctl status nixos-upgrade.timer`, `journalctl -u nixos-upgrade.service` [S1].

**Limitations:** No built-in build-verification gate; `--update-input` deprecation [S2]; does not update `flake.lock` (requires separate mechanism).

**Verdict:** Lowest complexity. Best starting point. Add GitHub Actions `flake.lock` automation (Approach 3) to complete the picture.

---

### Approach 2: Custom Systemd Services with Git Pull

Writing custom systemd services provides explicit control over the pull-rebuild sequence. The two-service pattern [S4]:

```nix
systemd.services.nixos-pull = {
  description = "Pull latest NixOS config from GitHub";
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
  script = ''
    set -euo pipefail
    REPO="/nix/var/nix/nixos-config"
    # Guard: only fast-forward merges on main
    cd "$REPO"
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$BRANCH" != "main" ]; then exit 1; fi
    git fetch origin
    git merge --ff-only origin/main
  '';
  serviceConfig.Type = "oneshot";
};

systemd.services.nixos-rebuild-switch = {
  description = "Rebuild and switch NixOS configuration";
  after = [ "nixos-pull.service" ];
  requires = [ "nixos-pull.service" ];
  script = ''
    nixos-rebuild switch --flake /nix/var/nix/nixos-config#hostname
  '';
  serviceConfig.Type = "oneshot";
};

systemd.timers.nixos-pull = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "04:00";
    RandomizedDelaySec = "1h";
    Persistent = true;
  };
};
```

This requires a **root-owned git clone** at `/nix/var/nix/nixos-config`. The user pushes changes to GitHub; root pulls from there. This eliminates the user→root escalation path [S8].

**Pros:** Fine-grained control; easy to add build verification as a gate; clean separation of concerns.
**Cons:** Requires managing a root-owned git clone; more nix configuration to maintain.

---

### Approach 3: GitHub Actions GitOps + `system.autoUpgrade` (Recommended)

This is the most widely validated, lowest-operational-overhead approach. Two independent pieces work together [S5][S6][S7]:

**Part 1 — GitHub Actions (in `.github/workflows/update-flake-lock.yml` of the config repo):**

```yaml
name: Weekly flake.lock update
on:
  schedule:
    - cron: "0 3 * * 1"   # Monday 03:00 UTC
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@v14
      - uses: DeterminateSystems/magic-nix-cache-action@v8
      - uses: DeterminateSystems/update-flake-lock@v24
        with:
          commit-msg: "flake: weekly lock file update"
          # Option A: open PR for review (safer)
          pr-title: "Weekly flake.lock update"
          pr-assignees: "your-github-username"
          # Option B: commit directly to main (for zero-touch operation)
          # Remove pr-* lines above and add:
          # git-push: true
```

**Part 2 — NixOS configuration on each machine:**

```nix
system.autoUpgrade = {
  enable = true;
  flake = "github:owner/repo#${config.networking.hostName}";
  dates = "04:00";          # 1 hour after GH Actions completes
  randomizedDelaySec = "1h";
  persistent = true;
  allowReboot = false;
  runGarbageCollection = true;
};
```

The time offset (Actions at 03:00, machines at 04:00) ensures `flake.lock` is committed before machines attempt to pull [S5]. All machines rebuild from the same `HEAD` commit, producing identical Nix store closures that the binary cache services efficiently.

**Pros:** Fully automated end-to-end; no local git clone management; uses GitHub Actions free tier (weekly runs ≈ minutes/month); battle-tested by multiple practitioners [S5][S7]; optional PR review gate.
**Cons:** Depends on GitHub Actions availability; requires Nix on the CI runner (~30s overhead); no built-in build verification before activation.

---

### Approach 4: Push-Based Tools (deploy-rs, Colmena)

| Feature | deploy-rs | Colmena | Relevance to family laptops |
|---------|-----------|---------|---------------------------|
| Deployment model | Push (operator → target) | Push (operator → target) | ✗ Requires active operator |
| Automatic rollback | Yes (unreachable check) | No | deploy-rs advantage |
| Multi-profile | Yes | Via NixOS modules | Both support |
| Secrets management | No built-in | Yes (built-in) | Colmena advantage |
| Parallel deploy | Yes | Yes | Both |
| Autonomous operation | No | No | ✗ Not suitable |
| Complexity | Medium | Medium | — |

Neither tool is designed for self-updating autonomous machines. They belong in scenarios where an administrator actively manages a fleet [S12][S13]. For the use case described in this report, they are not recommended.

---

### Approach 5: `nixos-autodeploy` (Polling-Based, Emerging)

`nixos-autodeploy` (announced June 2025) takes a different approach: rather than running `nixos-rebuild switch` on a timer, it continuously polls the upstream flake, computes the expected derivation, and only switches when the current system derivation matches a verified upstream state. Features include Prometheus metrics, dirty-state detection, and a preview path at `/run/upstream-system` [S11].

This is conceptually appealing for the family-laptop scenario but is currently early-stage with limited community adoption and testing. The derivation-matching gate provides stronger safety properties than a plain timer but adds operational complexity. **Not recommended for production use until wider community validation.**

---

### Build Verification Before Activation

The safety sequence for automated updates is:

```
1. nixos-rebuild build --flake github:owner/repo#hostname  → verify clean build (non-zero on failure)
2. if success → nixos-rebuild switch --flake github:owner/repo#hostname
3. nvd diff /run/booted-system /run/current-system  → log/email what changed
4. if failure → email build log to admin, do NOT switch
```

Implementing this as a custom systemd service (replacing `system.autoUpgrade`):

```nix
systemd.services.nixos-upgrade-verified = {
  description = "NixOS upgrade with build verification";
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
  path = [ pkgs.nix pkgs.git pkgs.nvd pkgs.msmtp ];
  script = ''
    set -euo pipefail
    FLAKE="github:owner/repo#${config.networking.hostName}"
    LOG=$(mktemp)

    if nixos-rebuild build --flake "$FLAKE" 2>&1 | tee "$LOG"; then
      nixos-rebuild switch --flake "$FLAKE"
      nvd diff /run/booted-system /run/current-system \
        | mail -s "NixOS updated: $(hostname)" admin@example.com
    else
      mail -s "NixOS build FAILED: $(hostname)" admin@example.com < "$LOG"
    fi
    rm -f "$LOG"
  '';
  serviceConfig = {
    Type = "oneshot";
    User = "root";
  };
};
```

**Limitations of `dry-activate`:** `nixos-rebuild dry-activate` shows what systemd units would change without activating. It can detect structural issues but does not catch runtime failures (e.g., a service binary that crashes when started). It is useful for human review but not a complete safety gate [S9].

---

### flake.lock Auto-Update Strategies

Three sub-approaches, compared:

| Strategy | How | Pros | Cons |
|----------|-----|------|------|
| **A: Manual** | Admin runs `nix flake update` locally, commits, pushes | Full review control | Requires discipline; easily neglected |
| **B: GH Actions → PR** | `update-flake-lock` opens a PR for review; admin approves | Review gate; CI can run checks | Requires admin action per merge |
| **C: GH Actions → direct commit** | `update-flake-lock` commits directly to `main` | Zero-touch; machines pick up automatically | No review gate; breaking nixpkgs update lands immediately |

For stable-channel configs tracking `nixos-24.11` or `nixos-25.05`, **Strategy C** (direct commit) is appropriate and widely used in production [S5][S7]. For configs with custom overlays, unstable inputs, or private packages, **Strategy B** (PR-based) provides a valuable safety net.

Track a **stable channel** (not `nixos-unstable`) to minimize risk from weekly lock updates. Stable channels receive only backported security fixes and critical bugfixes, making breaking changes rare.

Selective updates are available with `update-flake-lock` via the `inputs` parameter:

```yaml
- uses: DeterminateSystems/update-flake-lock@v24
  with:
    inputs: "nixpkgs home-manager"  # only update these; leave other inputs pinned
```

---

### User Notification Strategies

The fundamental challenge: `nixos-upgrade.service` runs as root in the **system D-Bus context**; `notify-send` targets the **user session D-Bus** — a different bus [S14].

| Method | How | Reliability | Best for |
|--------|-----|-------------|---------|
| **Email via msmtp** | `mail -s "..." admin@...` in ExecStartPost | High | Remote admins; machines not always logged in |
| **systembus-notify** | `services.systembus-notify.enable = true` | Medium (requires active session) | Desktop machines with logged-in user |
| **wall** | `wall "NixOS updated, reboot recommended"` | Medium | Single-user machines with terminal sessions |
| **Journal** | All output captured automatically | High (passive) | Retrospective audit; not proactive |
| **File-based** | Write status to `/run/nixos-update-status`; user session reads it | Medium | Custom status bar integrations |

For family laptop administration, **email** is the most practical: it works even when the machine is unmanned, delivers a record of changes, and requires no D-Bus plumbing. Use `nvd diff` output in the email body to show the administrator exactly what packages changed [S10].

---

### Security Considerations

**Risk:** User-owned config repo + root-executed auto-upgrade = user→root escalation via malicious config change [S8].

| Config model | Trust boundary | Risk level (personal machine) |
|-------------|----------------|------------------------------|
| `flake = inputs.self.outPath` (user-owned dir) | Local user account | Medium — user compromise → root |
| `flake = "github:owner/repo#host"` | GitHub account + 2FA | Low — attacker needs GitHub creds |
| Root-owned git clone at `/nix/var/nix/nixos-config` | Root access to the clone | Low — user can't modify |
| PR-based `flake.lock` updates | GitHub PR review | Lowest — explicit admin approval per update |

**Recommended mitigations for family laptops:**
1. Point `flake` to a GitHub URI directly — bypass local file permissions entirely [S8].
2. Enable 2FA on the GitHub account that owns the config repository.
3. Use branch protection rules on `main` to prevent force-pushes.
4. Use the PR-based `update-flake-lock` strategy for additional review gates on nixpkgs updates.

---

## Comparison Table

| Criterion | `system.autoUpgrade` | Custom Systemd + Git | GH Actions + Systemd | deploy-rs | Colmena | nixos-autodeploy |
|-----------|---------------------|---------------------|----------------------|-----------|---------|-----------------|
| Auto-pull config from GitHub | ✓ (with GitHub URI) | ✓ (git pull) | ✓ (nixos-rebuild --flake) | ✗ push-based | ✗ push-based | ✓ (polls) |
| Build verify before switch | ✗ no gate | ✓ add ExecStartPre | ✓ add build step | Partial | ✗ | ✓ derivation check |
| Applies cleanly without operator | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ |
| flake.lock auto-update | ✗ separate needed | ✗ separate needed | ✓ (GH Actions) | ✗ | ✗ | ✗ |
| Auto-commit flake.lock to repo | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| User/admin notification | ✗ (journal only) | ✓ (custom) | ✓ (custom) | Limited | Limited | ✓ (metrics) |
| Automatic rollback | ✗ | ✗ | ✗ | ✓ | ✗ | Partial |
| Handles offline laptops | ✓ (persistent) | ✓ | ✓ (persistent) | ✗ | ✗ | ✓ |
| Complexity (1=low, 5=high) | 1 | 3 | 3 | 5 | 5 | 4 |
| Deprecation/maturity risk | Medium (S2) | Low | Low | Low | Low | High (new) |
| Best for | Simple setups | Custom workflows | Family laptops ✓ | Managed fleets | Large fleets | Future use |

---

## Risks and Limitations

**Breaking nixpkgs changes propagate automatically.**
Weekly lock updates to a stable channel are low-risk; to `nixos-unstable` they are high-risk. Mitigation: stable channel + PR review gate [S5].

**No built-in rollback in most pull-based approaches.**
NixOS generations in the bootloader provide manual rollback, but no approach here (except deploy-rs and partially nixos-autodeploy) provides automated rollback. Previous generations must be retained. Mitigation: `nix.gc.options = "--delete-older-than 30d"` [S12].

**GitHub Actions runner requires Nix installed.**
`DeterminateSystems/update-flake-lock` v3+ no longer bundles Nix. Add `DeterminateSystems/nix-installer-action` step to workflows [S6].

**Clock skew between Actions completion and machine pull.**
If GitHub Actions is slow or delayed, machines may pull before `flake.lock` is committed. Mitigation: maintain ≥1 hour gap between Actions schedule and machine timer schedule [S5].

**`system.autoUpgrade` deprecation trajectory.**
The `--update-input` flag removal is active. Audit any existing configs for this flag before relying on `system.autoUpgrade` in production [S2].

**Disk space accumulation without GC.**
Each build adds a generation. `runGarbageCollection = true` or `programs.nh.clean.enable = true` is required for long-running automated systems [S1].

**Binary cache and GitHub API availability.**
`nixos-rebuild --flake github:...` requires both GitHub (for the flake tarball) and `cache.nixos.org` (for binaries). Offline or rate-limited machines will fail and retry on next timer cycle (if `persistent = true`). Cachix can mitigate cache availability for multi-machine setups.

---

## Recommendations

### Use Case A: Family Laptop Auto-Update

**Recommended configuration (start here, low complexity):**

```nix
# In nixos/hosts/<hostname>/configuration.nix or a shared profile
system.autoUpgrade = {
  enable = true;
  flake = "github:owner/repo#${config.networking.hostName}";
  flags = [ "--print-build-logs" ];
  operation = "boot";           # safer: activate on next reboot, not mid-session
  dates = "04:00";
  randomizedDelaySec = "1h";
  persistent = true;            # CRITICAL for laptops that sleep during scheduled window
  allowReboot = false;          # don't auto-reboot a family member's machine
  runGarbageCollection = true;
};
```

Using `operation = "boot"` means the new generation is set as the boot default but does not live-activate running services mid-session. The user gets the update on next login/reboot, which is far less disruptive for desktop use.

**Upgrade to build-verification (recommended for unattended machines):**

Replace `system.autoUpgrade` with a custom service that gates the switch on a successful build:

```nix
systemd.services.nixos-upgrade-verified = {
  description = "NixOS verified upgrade";
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
  path = with pkgs; [ nixos-rebuild nix git nvd msmtp ];
  script = ''
    set -euo pipefail
    FLAKE="github:owner/repo#${config.networking.hostName}"
    LOG=$(mktemp)

    if nixos-rebuild build --flake "$FLAKE" 2>&1 | tee "$LOG"; then
      nixos-rebuild boot --flake "$FLAKE"
      DIFF=$(nvd diff /run/booted-system /nix/var/nix/profiles/system 2>/dev/null || true)
      echo "$DIFF" | mail -s "NixOS update staged on $(hostname) — reboot to apply" admin@example.com
    else
      mail -s "NixOS build FAILED on $(hostname)" admin@example.com < "$LOG"
    fi
    rm -f "$LOG"
  '';
  serviceConfig = { Type = "oneshot"; User = "root"; };
};

systemd.timers.nixos-upgrade-verified = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "04:00";
    RandomizedDelaySec = "1h";
    Persistent = true;
  };
};
```

For user notification of pending reboot, add `services.systembus-notify.enable = true` and a post-switch `notify-send` call if the machine has a persistent desktop session. For most family laptops where the admin is remote, email is sufficient.

---

### Use Case B: Weekly flake.lock Update with Auto-Commit

**Step 1: Create `.github/workflows/update-flake-lock.yml` in the config repo:**

```yaml
name: Weekly flake.lock update
on:
  schedule:
    - cron: "0 3 * * 1"   # Monday 03:00 UTC — runs before machine timers at 04:00
  workflow_dispatch:       # allow manual trigger

jobs:
  update:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/nix-installer-action@v14

      - uses: DeterminateSystems/magic-nix-cache-action@v8

      - uses: DeterminateSystems/update-flake-lock@v24
        with:
          commit-msg: "flake: weekly lock file update"
          # OPTION A (zero-touch, direct commit to main):
          # Add to action inputs: git-push: true
          # Remove the pr-* lines below
          # OPTION B (PR for review — recommended if on nixos-unstable):
          pr-title: "Weekly flake.lock update"
          pr-assignees: "your-github-username"
          # Update only stable inputs, leave others pinned:
          inputs: "nixpkgs home-manager"
```

**Step 2: Configure `flake.nix` to track a stable channel:**

```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";  # stable
# NOT: "github:NixOS/nixpkgs/nixos-unstable"
```

**Step 3: Ensure machine timers run at least 1 hour after the Actions schedule.**
If Actions runs at 03:00 UTC, set `dates = "04:00"` (or later) on all machines. Adjust for timezone offsets if machines are in significantly different regions.

**Step 4: Track the workflow is running.**
GitHub sends email notifications to the repository owner on workflow failures. Enable notifications under repository Settings → Notifications to receive alerts if the weekly update fails (e.g., `nix flake update` errors due to a broken input).

---

## Appendix A: Evidence Table

| Source ID | Title | Publisher | Date | Quality | Key Claims |
|-----------|-------|-----------|------|---------|------------|
| S1 | Automatic system upgrades | wiki.nixos.org | 2024 | A | Full `system.autoUpgrade` option set and usage |
| S2 | Issue #349734: autoUpgrade deprecated flag | github.com/NixOS/nixpkgs | 2024 | A | `--update-input` deprecation |
| S3 | Best practices for auto-upgrades (flake) | discourse.nixos.org | 2023 | A | Remote URI pattern, lock file management |
| S4 | Keeping NixOS up to date with GH Actions | forrestjacobs.com | 2023 | B | Two-service pull+rebuild pattern |
| S5 | Keeping my NixOS fresh | blog.gothuey.dev | 2025 | A | GH Actions + systemd, 4 months production |
| S6 | update-flake-lock GitHub Action | github.com/DeterminateSystems | 2024 | A | Action options, PR/direct commit modes |
| S7 | Automatic NixOS Updates (cluster) | blog.nelsondane.me | 2024 | B | Multi-node GH Actions + systemd pattern |
| S8 | Security: auto-upgrades and config ownership | discourse.nixos.org | 2023 | A | Escalation risk, mitigations |
| S9 | nixos-rebuild wiki | wiki.nixos.org | 2024 | A | Subcommand semantics, exit codes |
| S10 | nvd: Nix/NixOS version diff tool | sr.ht/~khumba/nvd | 2024 | A | Generation diffing, notification use |
| S11 | nixos-autodeploy | discourse.nixos.org | 2025 | C | Derivation polling, Prometheus metrics |
| S12 | deploy-rs | github.com/serokell | 2024 | A | Push-based, automatic rollback |
| S13 | colmena | github.com/zhaofengli | 2024 | A | Push-based, parallel, secrets |
| S14 | Desktop notification after nixos-upgrade | discourse.nixos.org | 2024 | B | D-Bus gap, systembus-notify, email solutions |
| S15 | system.autoUpgrade options | mynixos.com | 2024 | A | Full option reference |
| S16 | auto-upgrade.nix source | github.com/NixOS/nixpkgs | 2024 | A | Implementation: rebootWindow, flake handling |
| S17 | Why auto-updates are hard | aires.fyi | 2024 | B | Problem framing, common pitfalls |
| S18 | Magic Deployments with nixos-rebuild | nixcademy.com | 2024 | A | `nixos-rebuild build` as pre-switch gate |

---

## Appendix B: Sources

1. **[S1]** NixOS Wiki — Automatic system upgrades: https://wiki.nixos.org/wiki/Automatic_system_upgrades
2. **[S2]** NixOS/nixpkgs Issue #349734: https://github.com/NixOS/nixpkgs/issues/349734
3. **[S3]** NixOS Discourse — Best practices for auto-upgrades: https://discourse.nixos.org/t/best-practices-for-auto-upgrades-of-flake-enabled-nixos-systems/31255
4. **[S4]** Forrest Jacobs — Keeping NixOS up to date with GitHub Actions: https://forrestjacobs.com/keeping-nixos-systems-up-to-date-with-github-actions/
5. **[S5]** Gaël Gothié — Keeping my NixOS fresh (2025): https://blog.gothuey.dev/2025/nixos-auto-upgrade/
6. **[S6]** DeterminateSystems — update-flake-lock: https://github.com/DeterminateSystems/update-flake-lock
7. **[S7]** Nelson Dane — Automatic NixOS Updates: https://blog.nelsondane.me/posts/automatic-nixos-updates/
8. **[S8]** NixOS Discourse — Security, auto-upgrades and config ownership: https://discourse.nixos.org/t/security-auto-upgrades-and-config-ownership/30970
9. **[S9]** NixOS Wiki — nixos-rebuild: https://wiki.nixos.org/wiki/Nixos-rebuild
10. **[S10]** khumba — nvd: https://sr.ht/~khumba/nvd
11. **[S11]** NixOS Discourse — nixos-autodeploy: https://discourse.nixos.org/t/nixos-autodeploy-robust-and-safe-auto-deployment-for-push-deploy-setups/66066
12. **[S12]** serokell — deploy-rs: https://github.com/serokell/deploy-rs
13. **[S13]** zhaofengli — colmena: https://github.com/zhaofengli/colmena
14. **[S14]** NixOS Discourse — Desktop notification after nixos-upgrade: https://discourse.nixos.org/t/desktop-notification-after-nixos-upgrade/63867
15. **[S15]** MyNixOS — system.autoUpgrade options: https://mynixos.com/nixpkgs/options/system.autoUpgrade
16. **[S16]** NixOS/nixpkgs — auto-upgrade.nix: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/tasks/auto-upgrade.nix
17. **[S17]** aires.fyi — Why is enabling automatic updates in NixOS so hard: https://aires.fyi/blog/why-is-enabling-automatic-updates-in-nixos-hard/
18. **[S18]** Nixcademy — Magic Deployments with nixos-rebuild: https://nixcademy.com/posts/nixos-rebuild/
