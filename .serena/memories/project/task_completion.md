# What to Do When a Task is Completed

## Before Committing
1. `just fmt` — format all .nix files with alejandra
2. `just lint` — check statix + deadnix
3. `just build` (or `just build <host>`) — verify it builds

## Optionally
4. `just diff` — review closure diff before activating
5. `just test` — activate without making boot default

## VCS
- Track any new files: `jj file track <path>`
- Use jujutsu (jj) for all version control — NOT raw git commands
- Main branch: `main`

## CI
- `nix flake check` runs alejandra formatting check — must pass
- Hosts auto-discovered from `nixos/hosts/` directory names in CI
