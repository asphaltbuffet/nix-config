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
update-switch host=hostname:
    nix flake update {{ flake }}
    nh os switch -H {{ host }} {{ flake }}

# ─────────────────────────────────────────────────────────────────────────────
# Maintenance
# ─────────────────────────────────────────────────────────────────────────────

# Update flake.lock to latest versions
[group('maintenance')]
update:
    nix flake update {{ flake }}

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
    agenix -e {{ flake }}/secrets/{{ name }}.age

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
