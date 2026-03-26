# update_flake_lock.yaml Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `update_flake_lock.yaml` to run every 3 days, handle same-day re-runs idempotently, and add a deduplicated package version diff summary to the PR body.

**Architecture:** Extend the existing single-file workflow with a new `diff` job that runs after `build`, builds the `main` branch per-host (Cachix cache hits), runs `nix store diff-closures` to compare old and new closures, deduplicates across hosts, and writes the result to an artifact. The `open-pr` job is updated to check for an existing PR and update its body rather than fail.

**Tech Stack:** GitHub Actions, Nix/Cachix, `nix store diff-closures`, `gh` CLI, `awk`/`sort`/`uniq` for deduplication.

---

## File Map

- Modify: `.github/workflows/update_flake_lock.yaml` — all changes live here

---

### Task 1: Update schedule to every 3 days at 04:00 EDT

**Files:**
- Modify: `.github/workflows/update_flake_lock.yaml`

- [ ] **Step 1: Update the cron expression**

Replace the existing `schedule` block:

```yaml
# Before
schedule:
  - cron: '0 4 * * 0' # runs weekly on Sunday at 04:00
```

```yaml
# After
schedule:
  # Every 3 days at 08:00 UTC (04:00 EDT / ~05:00 EST).
  # Scheduled for early morning ET so hosts are unlikely to be active
  # when autodeploy picks up the change. GitHub Actions has no timezone
  # support; the ~1hr DST drift is acceptable.
  - cron: '0 8 */3 * *'
```

- [ ] **Step 2: Verify the diff looks correct**

```bash
git diff .github/workflows/update_flake_lock.yaml
```

Expected: only the cron string and its comment changed.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/update_flake_lock.yaml
git commit -m "chore(ci): run flake lock update every 3 days at 04:00 EDT"
```

---

### Task 2: Add `diff` job — build main and compare closures per host

**Files:**
- Modify: `.github/workflows/update_flake_lock.yaml`

This job runs after `build`. For each host it:
1. Checks out `main` and builds it (Cachix cache hit — no recomputation).
2. Uses the store path emitted by the `build` job for the updated branch.
3. Runs `nix store diff-closures <main-path> <new-path>`.
4. Aggregates output across all hosts, deduplicates lines, then formats the summary.
5. Uploads the formatted PR body fragment as an artifact.

`★ Insight ─────────────────────────────────────`
`nix store diff-closures` output looks like:
`firefox: 130.0 → 131.0, x86_64-linux`
`glibc: 2.39 → 2.40, x86_64-linux`
Lines beginning with a package that was added have no left version; removed lines have no right version. This makes `awk` splitting on `→` reliable for counting.
`─────────────────────────────────────────────────`

The `build` job emits `store_path` as a matrix output — but GitHub Actions does not support consuming matrix outputs in downstream jobs directly. The workaround: upload the store path for each host as a small artifact from the `build` job, then download all of them in the `diff` job.

- [ ] **Step 1: Add store path artifact upload to the `build` job**

In the `build` job, after the existing "Write store path artifact" step, add a new step that always uploads a small artifact containing just the new store path (regardless of `publish-pages`):

```yaml
      - name: Upload new store path for diff
        uses: actions/upload-artifact@v4
        with:
          name: new-store-path-${{ matrix.host }}
          # Single-file artifact containing just the store path string
          path: /tmp/new-store-path-${{ matrix.host }}
```

And before that step, write the file:

```yaml
      - name: Write new store path for diff job
        env:
          HOST: ${{ matrix.host }}
          STORE_PATH: ${{ steps.build.outputs.store_path }}
        run: |
          printf '%s' "${STORE_PATH}" > "/tmp/new-store-path-${HOST}"
```

Place both steps after the existing `Build ${{ matrix.host }}` step.

- [ ] **Step 2: Add the `diff` job after the `build` job**

Insert the following job into `update_flake_lock.yaml` after the `build` job and before the `open-pr` job:

```yaml
  diff:
    name: "generate package diff"
    needs: [update, build]
    if: needs.update.outputs.branch != ''
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      artifact: pr-body
    steps:
      - uses: actions/checkout@v6

      - uses: DeterminateSystems/determinate-nix-action@v3
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - uses: cachix/cachix-action@v15
        with:
          name: nix-config-grue
          authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
          signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}

      - name: Download new store paths
        uses: actions/download-artifact@v4
        with:
          pattern: new-store-path-*
          merge-multiple: true
          path: /tmp/new-store-paths/

      - name: Build main branch closures and diff
        env:
          HOSTS: wendigo kushtaka snallygaster
        run: |
          mkdir -p /tmp/diffs

          for host in $HOSTS; do
            new_path=$(cat "/tmp/new-store-paths/new-store-path-${host}" 2>/dev/null || true)
            if [ -z "$new_path" ]; then
              echo "Skipping $host — no new store path artifact found"
              continue
            fi

            # Build main branch for this host (expected Cachix cache hit)
            main_path=$(nix build \
              ".#nixosConfigurations.${host}.config.system.build.toplevel" \
              --no-link \
              --print-out-paths)

            # Diff old (main) vs new (updated branch)
            nix store diff-closures "$main_path" "$new_path" \
              >> /tmp/diffs/raw-all.txt 2>/dev/null || true
          done

          # Deduplicate across hosts (same nixpkgs input → same changes on all hosts)
          sort -u /tmp/diffs/raw-all.txt > /tmp/diffs/deduped.txt

          # Count added (no →, has ε→ or just new version), removed, changed
          # diff-closures format: "pkg: old → new, arch" or "pkg: ε → new" or "pkg: old → ε"
          added=$(grep -c ' ε → ' /tmp/diffs/deduped.txt 2>/dev/null || echo 0)
          removed=$(grep -c ' → ε' /tmp/diffs/deduped.txt 2>/dev/null || echo 0)
          total=$(wc -l < /tmp/diffs/deduped.txt)
          changed=$((total - added - removed))

          # Build PR body fragment
          cat > /tmp/pr-body-diff.md << EOF
          ## Package changes

          **Added: ${added} | Removed: ${removed} | Changed: ${changed}**

          <details>
          <summary>Full diff</summary>

          \`\`\`
          $(cat /tmp/diffs/deduped.txt)
          \`\`\`

          </details>
          EOF

      - name: Upload PR body diff fragment
        uses: actions/upload-artifact@v4
        with:
          name: pr-body
          path: /tmp/pr-body-diff.md
```

- [ ] **Step 3: Verify the YAML is valid**

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/update_flake_lock.yaml'))" \
  && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/update_flake_lock.yaml
git commit -m "feat(ci): add nix store diff-closures summary to flake lock PR"
```

---

### Task 3: Update `open-pr` job to be idempotent and include the diff

**Files:**
- Modify: `.github/workflows/update_flake_lock.yaml`

The `open-pr` job needs to:
1. Depend on `diff` (in addition to `update` and `build`).
2. Download the `pr-body` artifact.
3. Assemble the full PR body (existing text + diff fragment).
4. Check whether a PR already exists for the branch.
5. If yes: update the body. If no: create a new PR.
6. Always run the auto-merge step.

- [ ] **Step 1: Update the `open-pr` job `needs` and add artifact download**

Replace the existing `open-pr` job with:

```yaml
  open-pr:
    name: "open pull request"
    needs: [update, build, diff]
    if: needs.update.outputs.branch != ''
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v6

      - name: Download PR body diff fragment
        uses: actions/download-artifact@v4
        with:
          name: pr-body
          path: /tmp/pr-body/

      - name: Assemble PR body
        env:
          BRANCH: ${{ needs.update.outputs.branch }}
        run: |
          cat > /tmp/full-pr-body.md << 'BODY'
          Automated update of `flake.lock` inputs.

          All hosts built successfully against this lock file.
          Merging will trigger `autodeploy.yaml`, which publishes store paths for pickup by `nixos-autodeploy`.
          BODY

          # Append diff fragment if present
          if [ -f /tmp/pr-body/pr-body-diff.md ]; then
            echo "" >> /tmp/full-pr-body.md
            cat /tmp/pr-body/pr-body-diff.md >> /tmp/full-pr-body.md
          fi

      - name: Create or update pull request
        id: pr
        env:
          # Must use a PAT here — PRs opened with GITHUB_TOKEN do not trigger
          # workflow runs, so status checks never fire and branch protection
          # rules can never be satisfied. A PAT makes the PR appear user-initiated.
          GH_TOKEN: ${{ secrets.GH_BOT_TOKEN }}
          BRANCH: ${{ needs.update.outputs.branch }}
        run: |
          body=$(cat /tmp/full-pr-body.md)

          # Check for an existing PR on this branch (same-day re-run guard)
          existing_url=$(gh pr list \
            --head "$BRANCH" \
            --base main \
            --json url \
            --jq '.[0].url' 2>/dev/null || true)

          if [ -n "$existing_url" ]; then
            echo "PR already exists: $existing_url — updating body"
            gh pr edit "$existing_url" --body "$body"
            echo "url=$existing_url" >> "$GITHUB_OUTPUT"
          else
            pr_url=$(gh pr create \
              --title "chore: update flake.lock" \
              --body "$body" \
              --head "$BRANCH" \
              --base main)
            echo "url=$pr_url" >> "$GITHUB_OUTPUT"
          fi

      - name: Enable auto-merge
        env:
          GH_TOKEN: ${{ secrets.GH_BOT_TOKEN }}
        run: gh pr merge "${{ steps.pr.outputs.url }}" --auto --rebase
```

- [ ] **Step 2: Verify the YAML is valid**

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/update_flake_lock.yaml'))" \
  && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/update_flake_lock.yaml
git commit -m "feat(ci): idempotent PR open/update for same-day re-runs"
```

---

### Task 4: Smoke-test via `workflow_dispatch`

**Files:** None — validation only.

- [ ] **Step 1: Trigger the workflow manually**

```bash
gh workflow run update_flake_lock.yaml --ref main
```

- [ ] **Step 2: Watch the run**

```bash
gh run watch
```

Expected: all four jobs (`update`, `build`, `diff`, `open-pr`) complete green. A PR is opened or updated on the `flake-lock-update-YYYYMMDD` branch.

- [ ] **Step 3: Trigger again on the same day to verify idempotency**

```bash
gh workflow run update_flake_lock.yaml --ref main
```

Expected: second run completes green; no duplicate PR is opened; the existing PR body is updated with a fresh diff.

- [ ] **Step 4: Inspect the PR body**

```bash
gh pr view --json body --jq .body \
  "$(gh pr list --head "flake-lock-update-$(date +%Y%m%d)" --json url --jq '.[0].url')"
```

Expected: body contains the static text, the `Added: N | Removed: N | Changed: N` summary line, and a `<details>` block with the full diff.
