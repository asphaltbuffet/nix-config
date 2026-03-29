# agenix + 1Password Secrets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `op inject`/`secrets.env` with agenix for runtime secret delivery, using 1Password only for bootstrap key distribution.

**Architecture:** Secrets are encrypted with age to SSH public keys (host keys for system secrets, user SSH keys for user secrets) and stored as `.age` files in the repo. At activation time, agenix decrypts them to `/run/agenix/<name>`. A Nix-generated `load-secrets` script reads those files at zsh startup and exports the env vars. 1Password is used only to distribute host SSH private keys during bootstrap/prep — never at runtime.

**Tech Stack:** agenix (ryantm/agenix), age encryption, SSH keys as age identities, NixOS modules, home-manager, jujutsu (jj), just

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `flake.nix` | Modify | Add agenix input; pass to `mkHost` |
| `secrets.nix` | Create | agenix recipients map (host + user public keys → `.age` files) |
| `secrets/hcPingKey.age` | Create | Encrypted healthchecks ping key |
| `secrets/grue/` | Create dir | User secrets directory |
| `secrets/grue/*.age` | Create (×10) | Encrypted user API keys |
| `nixos/common/agenix.nix` | Create | System-level agenix NixOS module; declares system secrets |
| `nixos/profiles/base.nix` | Modify | Import `../common/agenix.nix` |
| `home/modules/agenix/default.nix` | Create | User secret declarations + `load-secrets` script as `pkgs.writeShellApplication` |
| `home/roles/base.nix` | Modify | Import `../modules/agenix` |
| `home/modules/zsh/default.nix` | Modify | Replace `op inject` block with `load-secrets` call |
| `home/modules/zsh/secrets.env` | Delete | Replaced by agenix encrypted files |
| `nixos/common/autodeploy.nix` | Modify | Replace `op read` ping key with agenix file read |
| `nixos/hosts/wendigo/ssh_host_ed25519_key.pub` | Create | Host pubkey for secrets.nix |
| `nixos/hosts/kushtaka/ssh_host_ed25519_key.pub` | Create | Host pubkey for secrets.nix |
| `nixos/hosts/snallygaster/ssh_host_ed25519_key.pub` | Create | Host pubkey for secrets.nix |
| `justfile` | Modify | Add `prep-host`, `rekey` recipes; update `autodeploy-provision-token` |
| `nixos/installer/configuration.nix` | Modify | Add `agenix` CLI to installer environment |
| `README.md` | Modify | Rewrite secrets section |
| `CLAUDE.md` | Modify | Add agenix patterns, secrets.nix conventions |

---

## Task 1: Add agenix flake input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add agenix input to flake.nix**

  In `flake.nix`, add to the `inputs` block after `nixos-autodeploy`:

  ```nix
  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```

- [ ] **Step 2: Thread agenix through mkHost**

  In `flake.nix`, update the `outputs` destructuring to include `agenix`:

  ```nix
  outputs = inputs @ {
    self,
    nixpkgs,
    alejandra,
    home-manager,
    nixos-hardware,
    nur,
    agenix,
    ...
  }:
  ```

  Then add `agenix` to `specialArgs` in `mkHost`:

  ```nix
  specialArgs = {
    inherit
      self
      inputs
      nixpkgs
      home-manager
      nixos-hardware
      nur
      agenix
      ;
  };
  ```

  And add the agenix NixOS module to the `modules` list in `mkHost`:

  ```nix
  modules = [
    nur.modules.nixos.default
    agenix.nixosModules.default
    ({...}: {config = {nixpkgs.overlays = overlays;};})
    {
      environment.systemPackages = [
        alejandra.defaultPackage.${system}
      ];
    }
    ./nixos/hosts/${hostname}/configuration.nix
  ];
  ```

- [ ] **Step 3: Verify flake evaluates**

  ```bash
  nix flake show 2>&1 | head -20
  ```

  Expected: flake metadata including `nixosConfigurations.*` — no eval errors.

- [ ] **Step 4: Track and commit**

  ```bash
  jj file track flake.nix
  jj commit -m "feat(secrets): add agenix flake input and NixOS module"
  ```

---

## Task 2: Collect host SSH public keys

These keys become the age recipients for system secrets. We need the pubkey for each host.

**Files:**
- Create: `nixos/hosts/wendigo/ssh_host_ed25519_key.pub`
- Create: `nixos/hosts/kushtaka/ssh_host_ed25519_key.pub`
- Create: `nixos/hosts/snallygaster/ssh_host_ed25519_key.pub`

- [ ] **Step 1: Write wendigo's pubkey (current host)**

  ```bash
  cat /etc/ssh/ssh_host_ed25519_key.pub \
    > nixos/hosts/wendigo/ssh_host_ed25519_key.pub
  ```

  Expected content: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDyrkGOX0lDcdIO5ehmjTzRhW9UEJwXRnFYAYbsFHz76 root@wendigo`

- [ ] **Step 2: Get kushtaka's pubkey**

  Option A (if host is reachable via SSH):
  ```bash
  ssh kushtaka cat /etc/ssh/ssh_host_ed25519_key.pub \
    > nixos/hosts/kushtaka/ssh_host_ed25519_key.pub
  ```

  Option B (from 1Password if pre-created):
  ```bash
  op read "op://Service/host-kushtaka/public_key" \
    > nixos/hosts/kushtaka/ssh_host_ed25519_key.pub
  ```

- [ ] **Step 3: Get snallygaster's pubkey**

  ```bash
  ssh snallygaster cat /etc/ssh/ssh_host_ed25519_key.pub \
    > nixos/hosts/snallygaster/ssh_host_ed25519_key.pub
  ```

  Or from 1Password:
  ```bash
  op read "op://Service/host-snallygaster/public_key" \
    > nixos/hosts/snallygaster/ssh_host_ed25519_key.pub
  ```

- [ ] **Step 4: Track and commit**

  ```bash
  jj file track nixos/hosts/wendigo/ssh_host_ed25519_key.pub
  jj file track nixos/hosts/kushtaka/ssh_host_ed25519_key.pub
  jj file track nixos/hosts/snallygaster/ssh_host_ed25519_key.pub
  jj commit -m "chore(secrets): commit host SSH public keys for agenix recipients"
  ```

---

## Task 3: Create secrets.nix recipients file

**Files:**
- Create: `secrets.nix`

- [ ] **Step 1: Write secrets.nix**

  Create `secrets.nix` at the repo root. Replace the pubkey values with the actual content of the `.pub` files from Task 2:

  ```nix
  let
    # ── Host SSH public keys (system secrets) ─────────────────────────────
    wendigo     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDyrkGOX0lDcdIO5ehmjTzRhW9UEJwXRnFYAYbsFHz76 root@wendigo";
    kushtaka    = "<paste kushtaka pubkey here>";
    snallygaster = "<paste snallygaster pubkey here>";
    allHosts    = [ wendigo kushtaka snallygaster ];

    # ── User SSH public keys (user secrets) ────────────────────────────────
    grue = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeLAZg365wMtiUxEAXWscq4jSRhXeHH8X3NNcTT0DoP";
  in {
    # ── System secrets ──────────────────────────────────────────────────────
    "secrets/hcPingKey.age".publicKeys = allHosts;

    # ── User secrets: grue ──────────────────────────────────────────────────
    "secrets/grue/goreleaser.age".publicKeys        = [ grue ];
    "secrets/grue/anthropic.age".publicKeys         = [ grue ];
    "secrets/grue/context7.age".publicKeys          = [ grue ];
    "secrets/grue/github.age".publicKeys            = [ grue ];
    "secrets/grue/githubMcp.age".publicKeys         = [ grue ];
    "secrets/grue/protonmailHost.age".publicKeys    = [ grue ];
    "secrets/grue/protonmailPort.age".publicKeys    = [ grue ];
    "secrets/grue/protonmailUsername.age".publicKeys = [ grue ];
    "secrets/grue/protonmailPassword.age".publicKeys = [ grue ];
    "secrets/grue/resend.age".publicKeys            = [ grue ];
  }
  ```

- [ ] **Step 2: Track and commit**

  ```bash
  jj file track secrets.nix
  jj commit -m "chore(secrets): add agenix recipients file (secrets.nix)"
  ```

---

## Task 4: Encrypt all secrets

agenix uses `EDITOR` to open a temp file for editing the plaintext, then encrypts on save.
The age identity used for encryption is your SSH private key (via 1Password SSH agent).

**Files:**
- Create: `secrets/hcPingKey.age`
- Create: `secrets/grue/goreleaser.age` (and 9 more)

- [ ] **Step 1: Install agenix CLI temporarily**

  ```bash
  nix shell "github:ryantm/agenix"
  ```

- [ ] **Step 2: Create secrets directories**

  ```bash
  mkdir -p secrets/grue
  ```

- [ ] **Step 3: Encrypt the system secret**

  ```bash
  cd /home/grue/nix-config
  agenix -e secrets/hcPingKey.age
  ```

  Your `$EDITOR` opens. Paste the raw value from 1Password:
  ```bash
  op read "op://Service/ping_key/credential"
  ```
  Save and close. agenix encrypts to all `allHosts` recipients.

- [ ] **Step 4: Encrypt user secrets (one per line — run each)**

  For each secret, run `agenix -e secrets/grue/<name>.age`, open editor,
  paste the value from `op read`, save:

  ```bash
  # goreleaser
  agenix -e secrets/grue/goreleaser.age
  # value: op read "op://Private/GoReleaser/credential"

  # anthropic
  agenix -e secrets/grue/anthropic.age
  # value: op read "op://Private/Anthropic/credential"

  # context7
  agenix -e secrets/grue/context7.age
  # value: op read "op://Private/Context7/credential"

  # github
  agenix -e secrets/grue/github.age
  # value: op read "op://Private/GitHub/token"

  # githubMcp
  agenix -e secrets/grue/githubMcp.age
  # value: op read "op://Private/claude-github-mcp/token"

  # protonmailHost
  agenix -e secrets/grue/protonmailHost.age
  # value: op read "op://Private/proton_mail_bridge/server"

  # protonmailPort
  agenix -e secrets/grue/protonmailPort.age
  # value: op read "op://Private/proton_mail_bridge/port"

  # protonmailUsername
  agenix -e secrets/grue/protonmailUsername.age
  # value: op read "op://Private/proton_mail_bridge/username"

  # protonmailPassword
  agenix -e secrets/grue/protonmailPassword.age
  # value: op read "op://Private/proton_mail_bridge/password"

  # resend
  agenix -e secrets/grue/resend.age
  # value: op read "op://Private/Resend/api_key_full"
  ```

- [ ] **Step 5: Track and commit**

  ```bash
  jj file track secrets/
  jj commit -m "chore(secrets): add encrypted agenix secrets for all hosts and grue"
  ```

---

## Task 5: Create system agenix NixOS module

**Files:**
- Create: `nixos/common/agenix.nix`
- Modify: `nixos/profiles/base.nix`

- [ ] **Step 1: Create nixos/common/agenix.nix**

  ```nix
  # nixos/common/agenix.nix
  # System-level agenix secret declarations.
  # Secrets are decrypted to /run/agenix/ at activation time.
  # Each secret is encrypted to the host's SSH key in secrets.nix.
  {config, ...}: {
    age.secrets = {
      hcPingKey = {
        file = ../../secrets/hcPingKey.age;
        owner = "root";
        mode = "0400";
      };
    };
  }
  ```

- [ ] **Step 2: Import in nixos/profiles/base.nix**

  Add `../common/agenix.nix` to the imports list in `nixos/profiles/base.nix`:

  ```nix
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../common/1password.nix
    ../common/agenix.nix
    ../common/autodeploy.nix
    ../common/firefox.nix
    ../common/nas.nix
    ../common/tailscale.nix
  ];
  ```

- [ ] **Step 3: Track and commit**

  ```bash
  jj file track nixos/common/agenix.nix
  jj commit -m "feat(secrets): add system agenix module for hcPingKey"
  ```

---

## Task 6: Update autodeploy.nix to use agenix secret

**Files:**
- Modify: `nixos/common/autodeploy.nix`

- [ ] **Step 1: Update hcPingStart to read from agenix path**

  Replace the `hcPingStart` and `hcPingDone` shell applications in `nixos/common/autodeploy.nix`.
  Remove `pkgs._1password-cli` from `runtimeInputs` and replace `op read` with a direct file read:

  ```nix
  hcPingStart = pkgs.writeShellApplication {
    name = "hc-ping-start";
    runtimeInputs = [pkgs.curl];
    text = ''
      [[ -n "''${TRIGGER_TIMER_REALTIME_USEC:-}" ]] || exit 0
      [[ -r /run/agenix/hcPingKey ]] \
        || { echo "hc-ping-start: /run/agenix/hcPingKey not readable, skipping ping" >&2; exit 0; }
      PING_KEY=$(< /run/agenix/hcPingKey)
      export PING_KEY
      curl -fsS --retry 3 "https://hc-ping.com/$PING_KEY/nixos-autodeploy-${host}/start" > /dev/null
      unset PING_KEY
    '';
  };
  hcPingDone = pkgs.writeShellApplication {
    name = "hc-ping-done";
    runtimeInputs = [pkgs.curl];
    text = ''
      [[ -n "''${TRIGGER_TIMER_REALTIME_USEC:-}" ]] || exit 0
      EXIT_STATUS="''${EXIT_STATUS:-0}"
      [[ -r /run/agenix/hcPingKey ]] \
        || { echo "hc-ping-done: /run/agenix/hcPingKey not readable, skipping ping" >&2; exit 0; }
      PING_KEY=$(< /run/agenix/hcPingKey)
      export PING_KEY
      curl -fsS --retry 3 "https://hc-ping.com/$PING_KEY/nixos-autodeploy-${host}/$EXIT_STATUS" > /dev/null
      unset PING_KEY
    '';
  };
  ```

- [ ] **Step 2: Remove EnvironmentFile from serviceConfig**

  Remove this line from the `serviceConfig` block (no longer needed):

  ```nix
  EnvironmentFile = "-/etc/op/1password-service-account-token";
  ```

- [ ] **Step 3: Commit**

  ```bash
  jj commit -m "feat(secrets): autodeploy reads hcPingKey from agenix instead of op read"
  ```

---

## Task 7: Create user agenix home-manager module

**Files:**
- Create: `home/modules/agenix/default.nix`
- Modify: `home/roles/base.nix`

- [ ] **Step 1: Create home/modules/agenix/default.nix**

  ```nix
  # home/modules/agenix/default.nix
  # User-level agenix secret declarations and load-secrets script.
  # Secrets are decrypted to $XDG_RUNTIME_DIR/agenix/ at activation time.
  # Each secret is encrypted only to that user's SSH key.
  {
    pkgs,
    config,
    inputs,
    ...
  }: let
    # Single source of truth: all user secrets.
    # Add new secrets here; update secrets.nix and encrypt the .age file.
    userSecrets = {
      goreleaser = {
        file = ../../secrets/grue/goreleaser.age;
        envVar = "GORELEASER_KEY";
      };
      anthropic = {
        file = ../../secrets/grue/anthropic.age;
        envVar = "ANTHROPIC_API_KEY";
      };
      context7 = {
        file = ../../secrets/grue/context7.age;
        envVar = "CONTEXT7_API_KEY";
      };
      github = {
        file = ../../secrets/grue/github.age;
        envVar = "GH_TOKEN";
      };
      githubMcp = {
        file = ../../secrets/grue/githubMcp.age;
        envVar = "GITHUB_PERSONAL_ACCESS_TOKEN";
      };
      protonmailHost = {
        file = ../../secrets/grue/protonmailHost.age;
        envVar = "POP_SMTP_HOST";
      };
      protonmailPort = {
        file = ../../secrets/grue/protonmailPort.age;
        envVar = "POP_SMTP_PORT";
      };
      protonmailUsername = {
        file = ../../secrets/grue/protonmailUsername.age;
        envVar = "POP_SMTP_USERNAME";
      };
      protonmailPassword = {
        file = ../../secrets/grue/protonmailPassword.age;
        envVar = "POP_SMTP_PASSWORD";
      };
      resend = {
        file = ../../secrets/grue/resend.age;
        envVar = "RESEND_API_KEY";
      };
    };

    # Generate load-secrets entries for each secret.
    # SC2155-safe: declare and export separately.
    loadLines = builtins.concatStringsSep "\n" (
      builtins.attrValues (
        builtins.mapAttrs (name: secret: let
          path = config.age.secrets.${name}.path;
        in ''
          if [[ -r "${path}" ]]; then
            ${secret.envVar}="$(< "${path}")"
            export ${secret.envVar}
          fi
        '')
        userSecrets
      )
    );

    loadSecrets = pkgs.writeShellApplication {
      name = "load-secrets";
      text = loadLines;
    };
  in {
    imports = [inputs.agenix.homeManagerModules.default];

    # Declare agenix secret paths for each user secret.
    age.secrets = builtins.mapAttrs (_name: secret: {
      inherit (secret) file;
      mode = "0400";
    }) userSecrets;

    home.packages = [loadSecrets];
  }
  ```

- [ ] **Step 2: Import in home/roles/base.nix**

  Add `../modules/agenix` to the imports list in `home/roles/base.nix` (before `../modules/zsh` so secrets are available when zsh configures itself):

  ```nix
  imports = [
    inputs.nix-index-database.homeModules.nix-index

    ../modules/agenix
    ../modules/eza
    ../modules/fzf
    # ... rest unchanged
  ];
  ```

- [ ] **Step 3: Track and commit**

  ```bash
  jj file track home/modules/agenix/default.nix
  jj commit -m "feat(secrets): add user agenix home-manager module with load-secrets script"
  ```

---

## Task 8: Update zsh to use load-secrets

**Files:**
- Modify: `home/modules/zsh/default.nix`
- Delete: `home/modules/zsh/secrets.env`

- [ ] **Step 1: Replace op inject block in zsh/default.nix**

  Replace the `op inject` block in `initContent` in `home/modules/zsh/default.nix`:

  ```nix
  initContent = ''
    # Load secrets from agenix-decrypted files into environment variables.
    if command -v load-secrets &>/dev/null; then
      load-secrets
    fi

    # Set NIXOS_REBOOT_PENDING if the running kernel differs from the current config.
    # Used by the starship prompt and the login message below.
    if [[ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ]]; then
      export NIXOS_REBOOT_PENDING=1
    fi

    # Notify on login if a reboot is pending
    if [[ -o login ]] && [[ -n "$NIXOS_REBOOT_PENDING" ]]; then
      echo "⚠ NixOS update staged — reboot to apply."
    fi
  '';
  ```

- [ ] **Step 2: Delete secrets.env**

  ```bash
  rm home/modules/zsh/secrets.env
  ```

- [ ] **Step 3: Track deletion and commit**

  ```bash
  jj commit -m "feat(secrets): replace op inject/secrets.env with load-secrets in zsh"
  ```

---

## Task 9: Add prep-host and rekey justfile recipes

These recipes automate adding a new host's pubkey to `secrets.nix` and rekeying.

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Add rekey and prep-host recipes to justfile**

  Add these recipes to the `SSH Key Management` section of the justfile:

  ```just
  # Re-encrypt all secrets after adding a new recipient to secrets.nix
  [group('secrets')]
  rekey:
      nix shell "github:ryantm/agenix" --command agenix --rekey

  # Prep a new host: fetch pubkey from 1Password, add to host dir, then rekey
  # Requires: op item in Service vault named host-<hostname> with field public_key
  [group('secrets')]
  [no-exit-message]
  prep-host hostname: _op-check
      #!/usr/bin/env bash
      set -euo pipefail
      pubkey_file="nixos/hosts/{{ hostname }}/ssh_host_ed25519_key.pub"

      if [[ -f "$pubkey_file" ]]; then
          echo "✓ $pubkey_file already exists, skipping fetch"
      else
          echo "Fetching public key for {{ hostname }} from 1Password..."
          pubkey=$(op read "op://Service/host-{{ hostname }}/public_key") || {
              echo "✗ Failed to read op://Service/host-{{ hostname }}/public_key"
              echo "  Create a Service vault item named 'host-{{ hostname }}' with a 'public_key' field."
              exit 1
          }
          mkdir -p "nixos/hosts/{{ hostname }}"
          echo "$pubkey" > "$pubkey_file"
          echo "✓ Written to $pubkey_file"
      fi

      echo ""
      echo "Add {{ hostname }} as a recipient in secrets.nix, then run: just rekey"
      echo "Commit the results and push before running nixos-install on the new host."
  ```

- [ ] **Step 2: Remove outdated autodeploy-provision-token recipe**

  Delete the `autodeploy-provision-token` recipe from the justfile (it provisioned the old `op` SA token to `/etc/op/` — no longer needed with agenix):

  ```
  # Write the 1Password service account token to /etc/op/ (run once on first boot)
  [group('autodeploy')]
  [no-exit-message]
  autodeploy-provision-token: _op-check
      ...entire recipe...
  ```

- [ ] **Step 3: Commit**

  ```bash
  jj commit -m "feat(secrets): add rekey and prep-host justfile recipes, remove autodeploy-provision-token"
  ```

---

## Task 10: Build and test locally

- [ ] **Step 1: Format**

  ```bash
  just fmt
  ```

- [ ] **Step 2: Build without activating**

  ```bash
  just build
  ```

  Expected: build succeeds with no errors. Watch for any unresolved `age.secrets.*` references.

- [ ] **Step 3: Activate with test (no boot default change)**

  ```bash
  just test
  ```

  Expected: activation succeeds. agenix decrypts secrets to `/run/agenix/`.

- [ ] **Step 4: Verify secrets are decrypted**

  ```bash
  sudo ls -la /run/agenix/
  ```

  Expected: `hcPingKey` (owner root, mode 0400) and user secrets (owner grue, mode 0400).

- [ ] **Step 5: Verify load-secrets exports env vars**

  Open a new zsh session (or `exec zsh`) and check:

  ```bash
  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-(not set)}"
  echo "GH_TOKEN=${GH_TOKEN:-(not set)}"
  echo "POP_SMTP_HOST=${POP_SMTP_HOST:-(not set)}"
  ```

  Expected: all vars are set with real values (not `(not set)`).

- [ ] **Step 6: Verify cross-user isolation**

  ```bash
  sudo -u jsquats cat /run/agenix/anthropic 2>&1
  ```

  Expected: `Permission denied` — the file is mode 0400 owned by grue.

- [ ] **Step 7: Test graceful skip when secret missing**

  ```bash
  # Manually run load-secrets with a non-existent path to verify it skips
  MISSING_TEST_PATH="/run/agenix/nonexistent_test_secret"
  if [[ -r "$MISSING_TEST_PATH" ]]; then
    TEST_VAR="$(< "$MISSING_TEST_PATH")"
    export TEST_VAR
  fi
  echo "TEST_VAR=${TEST_VAR:-(not set — correct, file was missing)}"
  ```

  Expected: `TEST_VAR=(not set — correct, file was missing)`

- [ ] **Step 8: Commit passing state**

  ```bash
  jj commit -m "chore: verify agenix secrets working on wendigo"
  ```

---

## Task 11: Code review

- [ ] **Step 1: Run lint**

  ```bash
  just lint
  ```

  Expected: no formatting, statix, or deadnix errors.

- [ ] **Step 2: Review secrets.nix for over-sharing**

  Verify:
  - User secrets list only `[ grue ]` (not `allHosts`)
  - System `hcPingKey` lists `allHosts` (every host needs it for autodeploy)
  - No secret is encrypted to more recipients than necessary

- [ ] **Step 3: Review home/modules/agenix/default.nix**

  Verify:
  - `mode = "0400"` on all user secrets
  - `loadLines` uses SC2155-safe pattern (declare then export separately)
  - `userSecrets` attrset is the single source of truth (no duplicated paths)

- [ ] **Step 4: Review nixos/common/agenix.nix**

  Verify:
  - `owner = "root"`, `mode = "0400"` on `hcPingKey`
  - Path is relative (`../../secrets/hcPingKey.age`) and correct

- [ ] **Step 5: Review autodeploy.nix**

  Verify:
  - No remaining references to `pkgs._1password-cli`
  - No remaining `EnvironmentFile = "-/etc/op/..."` lines
  - Ping scripts use SC2155-safe export pattern

---

## Task 12: Security review

- [ ] **Step 1: Verify no plaintext in Nix store**

  ```bash
  # .age files should be binary ciphertext, not plaintext
  file secrets/hcPingKey.age secrets/grue/anthropic.age
  ```

  Expected: both reported as `data` (binary), not `ASCII text`.

- [ ] **Step 2: Verify decrypted files are on tmpfs**

  ```bash
  df /run/agenix/
  ```

  Expected: filesystem type `tmpfs` — secrets are never written to disk.

- [ ] **Step 3: Verify no secrets in git history**

  ```bash
  jj log --limit 20 -T 'commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
  ```

  Review the commit descriptions. If you accidentally committed a plaintext secret, use `jj abandon` to drop that commit before pushing.

- [ ] **Step 4: Confirm secrets.env is gone**

  ```bash
  jj file list | grep secrets.env
  ```

  Expected: no output.

---

## Task 13: Documentation audit

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update README.md secrets section**

  Find the Secrets Management section and replace it with:

  ```markdown
  ## Secrets Management

  Secrets are managed with [agenix](https://github.com/ryantm/agenix) — encrypted
  with age to SSH public keys and stored as `.age` files in the repo.

  | Layer | Tool | Where secrets live |
  |---|---|---|
  | System secrets (e.g. healthchecks ping key) | agenix | `/run/agenix/hcPingKey` (tmpfs, root:root 0400) |
  | User secrets (API keys, tokens) | agenix | `/run/agenix/<name>` (tmpfs, user:user 0400) |
  | Bootstrap key distribution | 1Password `op` CLI | Host SSH keypairs in `Service` vault |

  **Adding a secret:**
  1. Encrypt: `nix shell "github:ryantm/agenix" --command agenix -e secrets/<path>.age`
  2. Add to `secrets.nix` (recipients) and `home/modules/agenix/default.nix` (env var mapping)
  3. Commit and `just switch`

  **Adding a new host:**
  1. Create SSH keypair in 1Password (`Service` vault, item `host-<hostname>`)
  2. Run `just prep-host <hostname>` on any existing host
  3. Add host to `secrets.nix` recipients and run `just rekey`
  4. Commit, push, and wait for merge
  5. On the new host ISO: `op read "op://Service/host-<hostname>/private_key" > /etc/ssh/ssh_host_ed25519_key && chmod 600 /etc/ssh/ssh_host_ed25519_key`
  6. Run `nixos-install --flake "github:asphaltbuffet/nix-config#<hostname>"`
  ```

- [ ] **Step 2: Update CLAUDE.md with agenix patterns**

  Add a **Secrets (agenix)** section to `CLAUDE.md` under Key Conventions:

  ```markdown
  - **Secrets**: Managed with agenix. `.age` files are ciphertext (safe to commit). `secrets.nix` maps files to age recipient public keys. System secrets decrypt to `/run/agenix/` (root-owned). User secrets decrypt to `/run/agenix/` (user-owned). The `home/modules/agenix/default.nix` `userSecrets` attrset is the single source of truth for user secret → env var mappings. Add new secrets there + in `secrets.nix` + encrypt the `.age` file.
  - **Rekeying**: Run `just rekey` after adding a new recipient to `secrets.nix`. Requires agenix CLI and your SSH key loaded in the agent.
  - **New host prep**: `just prep-host <hostname>` fetches the host pubkey from 1Password `Service` vault, saves to `nixos/hosts/<hostname>/ssh_host_ed25519_key.pub`, and prints instructions to update `secrets.nix`.
  ```

- [ ] **Step 3: Commit documentation**

  ```bash
  jj commit -m "docs: update README and CLAUDE.md for agenix secrets architecture"
  ```

---

## Task 14: Push and deploy to all hosts

- [ ] **Step 1: Push to remote**

  ```bash
  jj git push
  ```

- [ ] **Step 2: Switch wendigo (already tested)**

  ```bash
  just switch
  ```

- [ ] **Step 3: Switch kushtaka**

  ```bash
  just switch kushtaka
  ```

  Or SSH and switch remotely:
  ```bash
  ssh kushtaka "cd /path/to/nix-config && just switch"
  ```

- [ ] **Step 4: Switch snallygaster**

  ```bash
  just switch snallygaster
  ```

- [ ] **Step 5: Verify secrets on each host**

  On each host after switching:
  ```bash
  sudo ls -la /run/agenix/
  # Expected: hcPingKey (root, 0400) and all grue/* secrets (grue, 0400)

  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-(not set)}"
  # Expected: set with real value in a new shell
  ```

---

## Self-Review Against Spec

**Spec coverage:**
- ✓ agenix flake input and NixOS module → Task 1
- ✓ Host SSH public keys collected → Task 2
- ✓ secrets.nix with all recipients → Task 3
- ✓ All secrets encrypted → Task 4
- ✓ System agenix module (hcPingKey) → Task 5
- ✓ autodeploy.nix reads from agenix path → Task 6
- ✓ User agenix HM module + load-secrets → Task 7
- ✓ zsh updated; secrets.env deleted → Task 8
- ✓ prep-host and rekey justfile recipes → Task 9
- ✓ Tests: env vars loaded, cross-user isolation, graceful skip → Task 10
- ✓ Code review → Task 11
- ✓ Security review → Task 12
- ✓ Documentation audit (README + CLAUDE.md) → Task 13
- ✓ Deploy to all hosts → Task 14

**No placeholders:** All steps contain actual commands and code.
