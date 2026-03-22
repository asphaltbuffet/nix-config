# NixOS Auto-Deploy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `nixos-autodeploy` into the repo so each opt-in host pulls its own NixOS config from Cachix on a timer, with CI building all hosts, pushing closures to `nix-config-grue.cachix.org`, and publishing store paths via GitHub Pages.

**Architecture:** CI builds every host on push to `main`, signs and pushes each system closure to Cachix, then writes each host's store path to a GitHub Pages artifact at `hosts/<hostname>/store-path`. Each opted-in host runs a systemd timer that fetches its URL and activates the new config via `nixos-autodeploy`. Hosts opt-in explicitly by setting `system.autoDeploy.enable = true` in their host config; auto-deploy is off by default everywhere.

**Tech Stack:** NixOS, `github:hlsb-fulda/nixos-autodeploy`, Cachix (`nix-config-grue`), GitHub Actions, GitHub Pages, `just`

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Modify | `flake.nix` | Add `nixos-autodeploy` input; pass to `mkHost` modules |
| Create | `nixos/common/autodeploy.nix` | Shared module: imports autodeploy NixOS module, sets URL from hostname, sensible defaults |
| Modify | `nixos/profiles/base.nix` | Add Cachix substituter + trusted-public-key |
| Create | `.github/workflows/autodeploy.yml` | Build matrix → Cachix push → GitHub Pages deploy |
| Create | `.autodeploy-skip/.gitkeep` | Marker directory for CI-level host pause files |
| Modify | `justfile` | Add `autodeploy-skip`, `autodeploy-resume`, `cachix-info` recipes |
| Modify | `README.md` | Document auto-deploy system, opt-in, exclusion mechanisms |

---

## Task 1: Add nixos-autodeploy flake input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Read the current flake inputs block**

  Confirm the last input before closing `}` so the new entry is placed correctly.

- [ ] **Step 2: Add the input**

  In `flake.nix`, add to the `inputs` block:

  ```nix
  nixos-autodeploy = {
    url = "github:hlsb-fulda/nixos-autodeploy";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```

- [ ] **Step 3: No outputs destructure change needed**

  Nix function argument patterns require valid identifiers — hyphenated names like `nixos-autodeploy` are **not valid** in destructuring patterns and would cause a parse error. Do NOT add it to the `outputs = inputs @ { ... }:` destructure.

  `inputs` is already passed as `specialArgs.inputs` (line 69 of `flake.nix`), so `inputs.nixos-autodeploy` is accessible inside any NixOS module. No additional changes to `specialArgs` or the `outputs` signature are needed.

- [ ] **Step 4: Format and check**

  ```bash
  just fmt && just check
  ```
  Expected: PASS (no new modules imported yet, so no options errors)

- [ ] **Step 5: Commit**

  ```bash
  jj file track flake.nix flake.lock
  jj commit -m "feat: add nixos-autodeploy flake input"
  ```

---

## Task 2: Create the shared autodeploy NixOS module

**Files:**
- Create: `nixos/common/autodeploy.nix`

This module **imports** the upstream nixos-autodeploy NixOS module (so the `system.autoDeploy` options exist) and **sets defaults** — URL constructed from hostname, safe `boot` switch mode, staggered delay. Hosts opt-in by setting `system.autoDeploy.enable = true`.

- [ ] **Step 1: Create `nixos/common/autodeploy.nix`**

  ```nix
  # nixos/common/autodeploy.nix
  # Configures nixos-autodeploy defaults. Hosts opt in by setting:
  #   system.autoDeploy.enable = true;
  {
    inputs,
    config,
    lib,
    ...
  }: {
    imports = [inputs.nixos-autodeploy.nixosModules.default];

    system.autoDeploy = {
      # URL is constructed automatically from the hostname.
      # CI publishes store paths at this location via GitHub Pages.
      url = lib.mkDefault "https://asphaltbuffet.github.io/nix-config/hosts/${config.networking.hostName}/store-path";

      # "boot" applies the new config on next reboot — safer for laptops than
      # "switch" (which activates immediately, potentially mid-session).
      # Override to "switch" in server host configs where instant rollout is preferred.
      switchMode = lib.mkDefault "boot";

      # Stagger deployment across hosts to avoid thundering-herd on Cachix.
      randomizedDelay = lib.mkDefault "30m";

      # Check once a day (systemd OnCalendar format).
      interval = lib.mkDefault "daily";
    };
  }
  ```

- [ ] **Step 2: Import the module in `base.nix`**

  In `nixos/profiles/base.nix`, add to the `imports` list:
  ```nix
  ../common/autodeploy.nix
  ```

- [ ] **Step 3: Track new file**

  ```bash
  jj file track nixos/common/autodeploy.nix
  ```

- [ ] **Step 4: Format and check**

  ```bash
  just fmt && just check
  ```
  Expected: PASS — `system.autoDeploy.enable` defaults to `false` so no behaviour changes yet.

- [ ] **Step 5: Commit**

  ```bash
  jj commit -m "feat: add shared autodeploy NixOS module"
  ```

---

## Task 3: Configure Cachix binary cache on all hosts

**Files:**
- Modify: `nixos/profiles/base.nix`

All hosts need to trust the `nix-config-grue` Cachix cache so `nixos-autodeploy` can fetch closures without root needing to add a substituter interactively.

> **Note:** The upstream `nixos-autodeploy` NixOS module may already configure `nix.settings` substituters for the cache. Check first to avoid conflicts.

- [ ] **Step 1: Inspect the upstream module for nix.settings**

  Run in the dev shell to see what the upstream module sets:
  ```bash
  nix eval github:hlsb-fulda/nixos-autodeploy#nixosModules.default \
    --apply 'mod: builtins.attrNames mod' 2>/dev/null || true
  ```

  Then read the module source directly:
  ```bash
  nix flake show github:hlsb-fulda/nixos-autodeploy
  cat $(nix build github:hlsb-fulda/nixos-autodeploy --print-out-paths 2>/dev/null)/module.nix 2>/dev/null || true
  ```

  If the module already configures `nix.settings.substituters` and `nix.settings.trusted-public-keys`, skip Steps 2–4 — the module handles it. If not, proceed with Steps 2–4.

- [ ] **Step 2: Get the Cachix cache public key**

  Run on any machine with `cachix` available (from dev shell):
  ```bash
  cachix describe nix-config-grue
  ```
  Look for the `Public Key` line — it looks like:
  `nix-config-grue.cachix.org-1:AAAA...==`

  Copy the full key including the `nix-config-grue.cachix.org-1:` prefix.

- [ ] **Step 3: Add substituter config to `base.nix`**

  In `nixos/profiles/base.nix`, **extend the existing `nix.settings` block** (lines 114–121) — do not create a second `nix.settings = { ... }` block, as that would conflict via module merging:
  ```nix
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
    auto-optimise-store = true;
    # Add these two new keys:
    substituters = ["https://nix-config-grue.cachix.org"];
    trusted-public-keys = ["nix-config-grue.cachix.org-1:<PASTE_KEY_HERE>"];
  };
  ```

- [ ] **Step 4: Format and check**

  ```bash
  just fmt && just check
  ```
  Expected: PASS

- [ ] **Step 5: Commit**

  ```bash
  jj commit -m "feat: configure nix-config-grue Cachix substituter on all hosts"
  ```

---

## Task 4: Create the CI auto-deploy workflow

**Files:**
- Create: `.github/workflows/autodeploy.yml`

The workflow has three jobs:
1. **`build`** (matrix): builds each host, pushes to Cachix, outputs the store path
2. **`publish`** (depends on `build`): assembles store-path files and deploys to GitHub Pages

CI respects `.autodeploy-skip/<hostname>` files: the host's config is still built and pushed to Cachix (keeps cache warm), but its store-path file is **not** written to the Pages artifact, so the host's autodeploy timer fetches a stale URL and does nothing new.

- [ ] **Step 1: Create the workflow file**

  ```yaml
  # .github/workflows/autodeploy.yml
  name: "auto-deploy: build & publish"

  on:
    push:
      branches: [main]
    workflow_dispatch:

  permissions:
    contents: read

  jobs:
    build:
      name: "build ${{ matrix.host }}"
      runs-on: ubuntu-latest
      permissions:
        contents: read
      strategy:
        fail-fast: false
        matrix:
          host: [wendigo, kushtaka, snallygaster]

      steps:
        - uses: actions/checkout@v4

        - uses: DeterminateSystems/determinate-nix-action@v3

        # cachix-action installs a Nix post-build hook that automatically pushes
        # all newly built store paths to the cache — no manual `cachix push` needed.
        - name: Install Cachix
          uses: cachix/cachix-action@v15
          with:
            name: nix-config-grue
            authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
            signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}

        - name: Build ${{ matrix.host }}
          id: build
          run: |
            # --print-out-paths emits the store path on stdout; capture it directly.
            # cachix-action's post-build hook pushes the path to the cache automatically.
            store_path=$(nix build \
              .#nixosConfigurations.${{ matrix.host }}.config.system.build.toplevel \
              --no-link \
              --print-out-paths)
            echo "store_path=${store_path}" >> "$GITHUB_OUTPUT"

        - name: Write store path artifact
          run: |
            if [ -f ".autodeploy-skip/${{ matrix.host }}" ]; then
              echo "⏭ ${{ matrix.host }} is in .autodeploy-skip — skipping store-path publish"
              exit 0
            fi
            mkdir -p "pages-artifact/hosts/${{ matrix.host }}"
            echo -n "${{ steps.build.outputs.store_path }}" \
              > "pages-artifact/hosts/${{ matrix.host }}/store-path"

        - name: Upload pages fragment
          uses: actions/upload-artifact@v4
          with:
            name: pages-${{ matrix.host }}
            path: pages-artifact/
            if-no-files-found: ignore

    publish:
      name: "publish to GitHub Pages"
      needs: build
      runs-on: ubuntu-latest
      permissions:
        pages: write
        id-token: write
      environment:
        name: github-pages
        url: ${{ steps.deploy.outputs.page_url }}

      steps:
        - name: Download all pages fragments
          uses: actions/download-artifact@v4
          with:
            pattern: pages-*
            merge-multiple: true
            path: pages-artifact/

        # Ensure the artifact directory is never empty — upload-pages-artifact fails
        # on an empty directory. This handles the edge case where all hosts are skipped.
        - name: Ensure non-empty artifact
          run: |
            if [ -z "$(ls -A pages-artifact/ 2>/dev/null)" ]; then
              mkdir -p pages-artifact
              echo "All hosts skipped — no store paths updated." > pages-artifact/index.html
            fi

        - name: Upload Pages artifact
          uses: actions/upload-pages-artifact@v3
          with:
            path: pages-artifact/

        - name: Deploy to GitHub Pages
          id: deploy
          uses: actions/deploy-pages@v4
  ```

- [ ] **Step 2: Track and verify structure**

  ```bash
  jj file track .github/workflows/autodeploy.yml
  ```

- [ ] **Step 3: Commit**

  ```bash
  jj commit -m "feat: add CI workflow for auto-deploy build, cachix push, and pages publish"
  ```

---

## Task 5: Create the `.autodeploy-skip` directory

**Files:**
- Create: `.autodeploy-skip/.gitkeep`

The directory must exist in the repo so the workflow's `[ -f ".autodeploy-skip/<host>" ]` check works correctly on a clean checkout.

- [ ] **Step 1: Create the marker file**

  ```bash
  mkdir -p .autodeploy-skip
  touch .autodeploy-skip/.gitkeep
  ```

- [ ] **Step 2: Track and commit**

  ```bash
  jj file track .autodeploy-skip/.gitkeep
  jj commit -m "chore: add .autodeploy-skip directory for CI-level host pausing"
  ```

---

## Task 6: Add justfile recipes for autodeploy management

**Files:**
- Modify: `justfile`

Add a new `Auto-Deploy` section with three recipes.

- [ ] **Step 1: Add the section to `justfile`**

  After the benchmarking section, add:

  ```just
  # ─────────────────────────────────────────────────────────────────────────────
  # Auto-Deploy
  # ─────────────────────────────────────────────────────────────────────────────

  # Pause CI store-path publishing for a host (build still runs, Cachix still updated)
  # Usage: just autodeploy-skip wendigo
  [group('autodeploy')]
  autodeploy-skip host:
      @if [ -f ".autodeploy-skip/{{ host }}" ]; then \
          echo "{{ host }} is already skipped"; \
      else \
          touch ".autodeploy-skip/{{ host }}" && \
          echo "Created .autodeploy-skip/{{ host }} — track and commit to activate"; \
      fi

  # Resume CI store-path publishing for a host
  # Usage: just autodeploy-resume wendigo
  [group('autodeploy')]
  autodeploy-resume host:
      @if [ ! -f ".autodeploy-skip/{{ host }}" ]; then \
          echo "{{ host }} is not currently skipped"; \
      else \
          rm ".autodeploy-skip/{{ host }}" && \
          echo "Removed .autodeploy-skip/{{ host }} — commit to resume auto-deploy"; \
      fi

  # Show the current published store path for a host (requires curl)
  # Usage: just autodeploy-status wendigo
  [group('autodeploy')]
  autodeploy-status host=hostname:
      @curl -sf "https://asphaltbuffet.github.io/nix-config/hosts/{{ host }}/store-path" \
          && echo "" \
          || echo "No store path published yet for {{ host }}"
  ```

- [ ] **Step 2: Verify just parses correctly**

  ```bash
  just help
  ```
  Expected: new `autodeploy` group appears in the output.

- [ ] **Step 3: Commit**

  ```bash
  jj commit -m "feat: add autodeploy justfile recipes"
  ```

---

## Task 7: Enable GitHub Pages for the repository

This is a one-time GitHub repository setting that cannot be done from code. It must be done via the GitHub web UI or `gh` CLI.

- [ ] **Step 1: Enable Pages via GitHub UI**

  Navigate to: `https://github.com/asphaltbuffet/nix-config/settings/pages`

  - **Source**: `GitHub Actions` (not a branch)
  - Save.

- [ ] **Step 2: Verify the workflow can deploy**

  Trigger the workflow manually:
  ```bash
  gh workflow run autodeploy.yml
  ```
  Or push a commit to `main`. Check that the `publish` job completes successfully.

- [ ] **Step 3: Verify a store path URL is reachable**

  ```bash
  just autodeploy-status wendigo
  ```
  Expected: prints a Nix store path like `/nix/store/abc123...`

---

## Task 8: Opt in the first host

Pick one host to enable first. `snallygaster` (X1 Carbon) makes a good first test since it has a different hardware profile from the T14s.

**Files:**
- Modify: `nixos/hosts/snallygaster/configuration.nix`

- [ ] **Step 1: Add auto-deploy opt-in**

  In `nixos/hosts/snallygaster/configuration.nix`, add inside the top-level attrset:
  ```nix
  system.autoDeploy.enable = true;
  ```

  The full file becomes:
  ```nix
  {...}: {
    imports = [
      ./hardware-configuration.nix

      ../../common/users.nix

      ../../profiles/base.nix
      ../../profiles/laptop/x1carbon.nix
    ];

    networking.hostName = "snallygaster";
    system.stateVersion = "26.05";

    # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
    # See .autodeploy-skip/snallygaster to pause without editing this file.
    system.autoDeploy.enable = true;
  }
  ```

- [ ] **Step 2: Build locally to verify**

  ```bash
  just build snallygaster
  ```
  Expected: build succeeds (the autodeploy systemd timer + service appear in the closure).

- [ ] **Step 3: Format and check**

  ```bash
  just fmt && just check
  ```
  Expected: PASS

- [ ] **Step 4: Commit**

  ```bash
  jj commit -m "feat(snallygaster): enable auto-deploy via nixos-autodeploy"
  ```

---

## Task 9: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a new `## Auto-Deploy` section**

  Insert after the `## Secrets Management` section:

  ```markdown
  ## Auto-Deploy

  Hosts that opt in receive automatic NixOS updates via
  [nixos-autodeploy](https://github.com/hlsb-fulda/nixos-autodeploy).

  **How it works:**

  1. On every push to `main`, CI builds all host configurations and pushes closures to
     the [`nix-config-grue` Cachix cache](https://app.cachix.org/cache/nix-config-grue).
  2. Each built store path is published to GitHub Pages at:
     `https://asphaltbuffet.github.io/nix-config/hosts/<hostname>/store-path`
  3. A systemd timer on each opted-in host fetches its URL and applies the new
     config (on next boot, by default).

  **Opting a host in:**

  Add to the host's `configuration.nix`:
  ```nix
  system.autoDeploy.enable = true;
  ```

  **Pausing auto-deploy for a host:**

  There are two complementary mechanisms:

  | Mechanism | Scope | How |
  |-----------|-------|-----|
  | CI skip file | Stops *publishing* new builds (host stays at last deployed version) | `just autodeploy-skip <hostname>` then track+commit the file |
  | Built-in divergence detection | Suspends *applying* updates after a manual `nixos-rebuild` | Automatic — `nixos-autodeploy` detects the divergence |

  ```bash
  # Pause publishing for a host (stops CI from updating the store-path URL)
  just autodeploy-skip wendigo
  jj file track .autodeploy-skip/wendigo
  jj commit -m "chore: pause auto-deploy for wendigo"

  # Resume
  just autodeploy-resume wendigo
  jj commit -m "chore: resume auto-deploy for wendigo"

  # Check what store path is currently published for a host
  just autodeploy-status wendigo
  ```

  **Disabling permanently:**

  Remove `system.autoDeploy.enable = true` from the host config (or set it to `false`).
  ```

- [ ] **Step 2: Commit**

  ```bash
  jj commit -m "docs: document auto-deploy system in README"
  ```

---

## Task 10: Push and verify end-to-end

- [ ] **Step 1: Push to remote**

  ```bash
  jj git push
  ```

- [ ] **Step 2: Watch the CI workflow**

  ```bash
  gh run watch
  ```
  Expected: all three `build <host>` jobs succeed; `publish` job deploys to Pages.

- [ ] **Step 3: Verify store paths are live**

  ```bash
  just autodeploy-status wendigo
  just autodeploy-status kushtaka
  just autodeploy-status snallygaster
  ```
  Expected: each prints a `/nix/store/...` path.

- [ ] **Step 4: Verify snallygaster autodeploy service**

  On snallygaster after `just switch snallygaster`:
  ```bash
  systemctl status nixos-autodeploy.timer
  systemctl status nixos-autodeploy.service
  ```
  Expected: timer is active; service last ran successfully (or is pending its first scheduled run).

---

## Notes

- **`switchMode = "boot"`** is set as the default in `autodeploy.nix`. This means the new config becomes the boot default but the running system is not restarted. Override to `"switch"` in server host configs where immediate activation is preferred.
- **Cachix secret names**: `CACHIX_AUTH_TOKEN` and `CACHIX_SIGNING_KEY` must be set in the GitHub repo's Actions secrets (`Settings → Secrets → Actions`).
- **`jj file track` not `git add`**: New files must be tracked with `jj file track <path>` before `just build` or `just check` can see them (the flake copies sources via `self`).
- **GitHub Pages must be enabled** in repo settings before the `publish` job will succeed. Source must be set to `GitHub Actions` (not a branch).
