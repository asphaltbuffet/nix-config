# Jujutsu (jj) as version control instead of plain git

This repo uses jujutsu (`jj`) in colocated mode (`.jj/` sits alongside `.git/`). All VCS operations use `jj` commands; `git` commands are not used directly except by tooling that requires them (CI, GitHub).

jj's working-copy-as-commit model eliminates the index/staging-area mental overhead that causes frequent mistakes in flake repos (e.g. forgetting `git add` on new files before `nix flake check`). The colocated mode means GitHub, CI, and any git-native tooling continue to work unchanged. The main practical constraint: jj has a single mutable working copy (`@`), so parallel agents or worktrees that need to commit must operate sequentially — parallel read-only work is fine.
