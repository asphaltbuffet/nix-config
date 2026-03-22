# https://just.systems

hostname := `hostname`
flake := justfile_directory()

[private]
default: help

# ─────────────────────────────────────────────────────────────────────────────
# Building & Deploying
# ─────────────────────────────────────────────────────────────────────────────

# Build configuration without activating
[group('build')]
build host=hostname:
    nh os build -H {{ host }} {{ flake }}

# Build the installer ISO (flash with: dd if=result/iso/*.iso of=/dev/sdX bs=4M)
[group('build')]
iso:
    nix build {{ flake }}#installer
    @echo "ISO: $(ls -1 result/iso/*.iso 2>/dev/null || echo 'build failed')"

# Boot the installer ISO in a QEMU VM for testing (creates a 20GB scratch disk)
# SSH in with: ssh -p 2222 nixos@localhost  (password: nixos)
# scp from VM:  scp -P 2222 nixos@localhost:/home/nixos/... ./...
# Exit QEMU:   Ctrl+A then X  (or run 'poweroff' inside the VM)
[group('build')]
vm disk="vm-disk.qcow2":
    #!/usr/bin/env bash
    set -euo pipefail
    iso=$(ls -1 result/iso/*.iso 2>/dev/null | head -1)
    if [[ -z "$iso" ]]; then
        echo "No ISO found — run 'just iso' first"
        exit 1
    fi
    if [[ ! -f "{{ disk }}" ]]; then
        echo "Creating scratch disk: {{ disk }} (20G)"
        nix shell nixpkgs#qemu_test --command qemu-img create -f qcow2 "{{ disk }}" 20G
    fi
    echo "Booting $iso — SSH available at localhost:2222 (password: nixos)"
    echo "To remove the scratch disk afterwards: rm {{ disk }}"
    echo "Exit: Ctrl+A then X"
    nix shell nixpkgs#qemu_test --command qemu-system-x86_64 \
        -m 4096 \
        -smp 2 \
        -enable-kvm \
        -cdrom "$iso" \
        -drive file="{{ disk }}",format=qcow2 \
        -boot order=d \
        -nic user,model=virtio,hostfwd=tcp::2222-:22 \
        -nographic

# Build and activate configuration (makes it boot default)
[group('build')]
switch host=hostname:
    nh os switch -H {{ host }} {{ flake }}

# Build and activate without making it boot default
[group('build')]
test host=hostname:
    nh os test -H {{ host }} {{ flake }}

# Update flake inputs and switch in one step
[group('build')]
update-switch host=hostname: update
    nh os switch -H {{ host }} {{ flake }}

# ─────────────────────────────────────────────────────────────────────────────
# Maintenance
# ─────────────────────────────────────────────────────────────────────────────

# Update flake.lock to latest versions
[group('maintenance')]
update:
    nix flake update

# Remove old generations and garbage collect
[group('maintenance')]
clean generations="3" since="5d":
    nh clean all --keep {{ generations }} -K {{ since }} -a

# Show what changed between current and new config
[group('maintenance')]
diff host=hostname:
    nh os build -H {{ host }} {{ flake }}

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Format all nix files with alejandra
[group('dev')]
fmt:
    alejandra -qq {{ flake }}

# Check flake outputs for errors
[group('dev')]
check:
    nix flake check {{ flake }}

# Show flake inputs and their versions
[group('dev')]
inputs:
    nix flake metadata {{ flake }}

# ─────────────────────────────────────────────────────────────────────────────
# SSH Key Management
# ─────────────────────────────────────────────────────────────────────────────

# Show the current SSH public key from 1Password (for adding to servers/GitHub)
[group('ssh')]
ssh-pubkey:
    @op item get "grue-main" --fields label="public key" 2>/dev/null || \
        echo "Error: 1Password CLI not authenticated. Run: op signin"

# Verify 1Password SSH agent is running and keys are available
[group('ssh')]
ssh-agent-check:
    #!/usr/bin/env bash
    set -euo pipefail
    socket="$HOME/.1password/agent.sock"
    if [[ -S "$socket" ]]; then
        echo "✓ 1Password SSH agent socket exists"
        if SSH_AUTH_SOCK="$socket" ssh-add -l &>/dev/null; then
            echo "✓ Agent is responding with keys"
        else
            echo "✗ Agent socket exists but no keys returned"
            echo "  Is 1Password unlocked? Is SSH agent enabled in Settings → Developer?"
            exit 1
        fi
    else
        echo "✗ Agent socket not found at $socket"
        echo "  Start 1Password and enable SSH agent in Settings → Developer"
        exit 1
    fi

# Guided SSH key rotation workflow
[group('ssh')]
ssh-rotate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== SSH Key Rotation Guide ==="
    echo ""
    echo "Step 1: Generate a new SSH key in 1Password:"
    echo "  New Item → SSH Key → name: grue-main-$(date +%Y%m) → Ed25519 → Generate"
    echo "  Copy the public key."
    echo ""
    echo "Step 2: Update home/modules/ssh/default.nix:"
    echo "  Replace signingKeyPub with the new public key string."
    echo ""
    echo "Step 3: Update nixos/common/users.nix:"
    echo "  Replace openssh.authorizedKeys.keys entry for grue."
    echo ""
    echo "Step 4: just switch (on all hosts)"
    echo "Step 7: Update GitHub SSH keys (auth + signing)."
    echo "Step 8: Update authorized_keys on any external servers."
    echo ""
    echo "Verify with: just ssh-verify"

# Verify SSH + signing setup end-to-end
[group('ssh')]
ssh-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== SSH Setup Verification ==="
    echo ""

    socket="$HOME/.1password/agent.sock"

    # Agent check
    if [[ -S "$socket" ]] && SSH_AUTH_SOCK="$socket" ssh-add -l &>/dev/null; then
        echo "  1Password agent  ✓"
    else
        echo "  1Password agent  ✗  (not responding)"
    fi

    # GitHub auth
    # Note: `ssh -T git@github.com` always exits 1 (GitHub rejects shell access).
    # Capture output separately so pipefail doesn't treat the ssh exit code as failure.
    gh_output=$(SSH_AUTH_SOCK="$socket" ssh -T git@github.com 2>&1 || true)
    if echo "$gh_output" | grep -q "successfully authenticated"; then
        echo "  GitHub SSH auth  ✓"
    else
        echo "  GitHub SSH auth  ✗  (debug: SSH_AUTH_SOCK=$socket ssh -T git@github.com)"
    fi

    # Git signing config — use 'git config' (no --global) to read effective merged value.
    # This avoids a legacy ~/.gitconfig from shadowing home-manager's config.
    if git config gpg.format 2>/dev/null | grep -q "ssh"; then
        echo "  Git signing      ✓"
    else
        echo "  Git signing      ✗  (check home/modules/ssh/default.nix)"
    fi

    echo ""
    echo "Done."

# Print instructions for adding a new host's public key to secrets.nix
# Usage: just ssh-add-host <hostname> <pubkey>
# Example: just ssh-add-host myserver "ssh-ed25519 AAAA..."
# NOTE: This recipe is advisory — it prints instructions but does not edit files.
[group('ssh')]
ssh-add-host hostname pubkey:
    @echo "1. Add to secrets/secrets.nix in the 'let' block:"
    @echo "     {{ hostname }} = \"{{ pubkey }}\";"
    @echo ""
    @echo "2. Add '{{ hostname }}' to the systems = [...] list."
    @echo ""
    @echo "3. Run: just switch"

# ─────────────────────────────────────────────────────────────────────────────
# Info
# ─────────────────────────────────────────────────────────────────────────────

# List available hosts
[group('info')]
hosts:
    @ls -1 {{ flake }}/nixos/hosts/

# Show current system generation info
[group('info')]
generation:
    @nixos-rebuild list-generations | head -5

# Show available commands
[group('info')]
help:
    @just --list --unsorted

# ─────────────────────────────────────────────────────────────────────────────
# Benchmarking
# ─────────────────────────────────────────────────────────────────────────────

# Create benchmark
[group('benchmarking')]
benchmark:
    nix run {{ flake }}#benchmark

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
        jj file track ".autodeploy-skip/{{ host }}" && \
        echo "Created .autodeploy-skip/{{ host }} — commit to activate"; \
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
    @curl -sfL "https://asphaltbuffet.github.io/nix-config/hosts/{{ host }}/store-path" \
        && echo "" \
        || echo "No store path published yet for {{ host }}"
