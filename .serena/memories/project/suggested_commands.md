# Suggested Commands

## Build & Deploy
```bash
just build              # Build config without activating (current host)
just build <host>       # Build for a specific host
just switch             # Build and activate (makes it boot default)
just test               # Build and activate without making it boot default
just diff               # Build and diff closure against /run/current-system (uses nvd)
```

## Quality Checks
```bash
just lint               # Check formatting (alejandra), linting (statix), dead code (deadnix)
just fix                # Apply formatting and linting fixes
just fmt                # Format all .nix files with alejandra
just check              # Run nix flake check (includes formatting check)
```

## Secrets
```bash
just rekey              # Re-encrypt secrets after adding a new recipient
just prep-host <name>   # Fetch host pubkey from 1Password, save to nixos/hosts/<name>/
```

## Dev Environment
```bash
nix develop             # Enter dev shell (provides nixd, alejandra, statix, deadnix, just)
```

## VCS (jujutsu)
```bash
jj file track <path>    # Track new files before build (flake copies via self)
jj workspace add <path> --name <name>   # Isolated workspace (NOT git worktree add)
```

## Preferred CLI Tools
- `fd` instead of `find`
- `rg` instead of `grep`
- `sd` instead of `sed`
- `jq` for JSON processing
- `yq -e '.' file.yaml` for YAML validation (NOT python3)
