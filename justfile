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
# Secrets (agenix)
# ─────────────────────────────────────────────────────────────────────────────

# Edit an encrypted secret (e.g., just secret-edit goreleaser)
[group('secrets')]
secret-edit name:
    cd {{ flake }}/secrets && agenix -e {{ name }}.age

# Re-encrypt all secrets after adding new keys
[group('secrets')]
secret-rekey:
    cd {{ flake }}/secrets && agenix -r

# List all available secrets
[group('secrets')]
secret-list:
    @ls -1 {{ flake }}/secrets/*.age 2>/dev/null | xargs -I{} basename {} .age

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
