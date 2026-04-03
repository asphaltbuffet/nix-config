# CI & GitHub Actions SOP

## `permissions:` and Reusable Workflows

The workflow-level `permissions:` block in a *calling* workflow is a hard ceiling — any permission not listed there is implicitly `none`, and the called workflow's jobs cannot exceed it.

Whenever you add or change a permission in a job inside `build-hosts.yaml`, audit ALL callers (`autodeploy.yaml`, `pr-check.yaml`, `update_flake_lock.yaml`) and ensure that permission is present at their workflow level too. Omitting it produces a "nested job is requesting X, but is only allowed none" validation error.

Contrast: `permissions:` on a `workflow_call` *job* block (not the workflow itself) IS silently ignored — only the called workflow's own job-level declarations govern.

## `git push --force-with-lease` on CI

Fresh runners have no tracking refs. Run `git fetch origin "$branch" || true` before pushing to establish the tracking ref, or `--force-with-lease` rejects same-day re-runs with "stale info".

## GitHub Actions Matrix Outputs

Matrix job outputs cannot be consumed by downstream jobs directly. Pass per-matrix-leg data via artifact upload/download (e.g., `upload-artifact` per host, `download-artifact` with `pattern:` + `merge-multiple: true` downstream).

## `build-hosts.yaml` is Shared

Called by `autodeploy.yaml`, `pr-check.yaml`, and `update_flake_lock.yaml`. New steps added there affect all callers — gate them behind a boolean input with `default: false` (see `publish-pages` and `upload-store-path-for-diff` as examples).

## Auto-Deploy

`nixos-autodeploy` is active (see `nixos/common/autodeploy.nix`). Hosts opt in with `system.autoDeploy.enable = true`. Store paths are published to GitHub Pages; verify with `just autodeploy-status <host>`. switchMode defaults to `"smart"` (applies immediately for non-kernel updates; kernel updates wait for reboot).

## `just ssh-verify`

Uses `|| true` to absorb `ssh -T git@github.com`'s exit code 1 (GitHub always returns 1 for non-shell SSH). Without this, `set -euo pipefail` causes false failures.
