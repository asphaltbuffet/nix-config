# Suggested Commands

## Build & Activation
```bash
just build              # Build config without activating (current host)
just build <host>       # Build for a specific host
just switch             # Build and activate (makes it boot default)
just test               # Build and activate without making it boot default
just diff               # Build and diff closure against /run/current-system
```

## Code Quality
```bash
just lint               # Check formatting (alejandra), linting (statix), dead code (deadnix)
just fix                # Apply formatting and linting fixes
just fmt                # Format all .nix files with alejandra
just check              # Run nix flake check (includes formatting check)
```

## Secrets & Updates
```bash
just rekey              # Rekey agenix secrets after adding a recipient
just update             # Update flake.lock inputs
```

## Dev Shell
```bash
nix develop             # Enter dev shell (provides nixd, alejandra, statix, deadnix, just)
```

## VCS (jujutsu)
```bash
jj file track <path>    # Track new files (REQUIRED before just build can see them)
jj workspace add <path> --name <name>  # Isolated workspace (not git worktree add)
```

## Preferred CLI Tools
- `fd` instead of `find`
- `rg` instead of `grep`  
- `sd` instead of `sed` (in-place substitution)
- `jq` for JSON processing
- `yq -e '.' file.yaml` for YAML validation
