---
name: use-jj
description: Use jujutsu (jj) instead of git for version control whenever a .jj/ directory is detected in the working directory or any ancestor. Triggers automatically for all VCS operations — committing, branching, status checks, pushing, pulling, viewing history, creating workspaces, managing bookmarks — whenever the repo uses jj. Never fall back to git commands in a jj repo. Also triggers when the user mentions "jj", "jujutsu", or asks for help with jj commands.
context: fork
---

# jujutsu (jj) VCS Skill

## Repo Detection

Before any VCS operation, confirm this is a jj repo:

```bash
jj root 2>/dev/null && echo "jj repo" || echo "not a jj repo"
```

If `jj root` fails, stop and inform the user — this skill should not have triggered.

Colocated repos have both `.jj/` and `.git/`. In these repos, **always use `jj` commands** —
never `git` directly, since jj manages the git backend and concurrent git commands can corrupt state.

## Core Mental Model

jj differs from git in a few fundamental ways worth keeping in mind:

- **No staging area**: every file change is automatically part of the current commit (`@`). There is
  no `git add` — files are always tracked.
- **Mutable history**: you can freely edit any commit's description, content, or position in the
  graph. `jj describe`, `jj squash`, and `jj rebase` are everyday operations.
- **Working copy is a commit**: `@` refers to the current working-copy commit. It's always "dirty"
  until you run `jj new` to move forward.
- **Bookmarks, not branches**: jj calls them bookmarks (`jj bookmark`). In colocated repos, bookmarks
  sync to git branches.

## Command Reference

### Status & History

| Task | jj command | git equivalent |
|------|-----------|----------------|
| Show status | `jj status` | `git status` |
| Show log | `jj log` | `git log --oneline --graph` |
| Show diff of working copy | `jj diff` | `git diff HEAD` |
| Show diff of specific commit | `jj diff -r <rev>` | `git show <sha>` |
| Show file at revision | `jj file show -r <rev> <path>` | `git show <sha>:<path>` |

### Committing

| Task | jj command | git equivalent |
|------|-----------|----------------|
| Describe current change | `jj describe -m "message"` | `git commit --amend -m` |
| Commit and start new change | `jj commit -m "message"` | `git commit -m` + `git checkout -b` |
| Create new empty change | `jj new` | `git commit --allow-empty` + checkout |
| Amend current change | `jj describe` (edit description) or just edit files | `git add -p && git commit --amend` |
| Split a change interactively | `jj split` | `git add -p && git commit` |
| Squash into parent | `jj squash` | `git rebase -i HEAD~2` (fixup) |

**Important**: In this repo, commits are signed. The jj config at `~/.config/jj/config.toml` sets
`signing.sign-all = true` with SSH backend — this happens automatically, no flags needed.

### Bookmarks (Branches)

| Task | jj command | git equivalent |
|------|-----------|----------------|
| List bookmarks | `jj bookmark list` | `git branch -a` |
| Create bookmark at current change | `jj bookmark create <name>` | `git checkout -b <name>` |
| Move bookmark to current change | `jj bookmark set <name>` | `git branch -f <name>` |
| Delete bookmark | `jj bookmark delete <name>` | `git branch -d <name>` |
| Track remote bookmark | `jj bookmark track <name>@origin` | `git branch --track` |
| Advance bookmark to tip | `jj bookmark move --from <rev> --to <rev>` | `git branch -f` |

The custom alias `jj tug` is configured: it advances the nearest ancestor bookmark to `@-`
(the parent of the working copy). Use it to "slide a branch pointer forward" after committing.

### Remote Operations

| Task | jj command | git equivalent |
|------|-----------|----------------|
| Fetch from remote | `jj git fetch` | `git fetch` |
| Push bookmarks | `jj git push` | `git push` |
| Push specific bookmark | `jj git push -b <name>` | `git push origin <name>` |
| Push and create remote bookmark | `jj git push -b <name> --allow-new` | `git push -u origin <name>` |
| Force push (with lease equivalent) | `jj git push --force-with-lease` | `git push --force-with-lease` |

### Navigation & Revsets

| Task | jj command | git equivalent |
|------|-----------|----------------|
| Check out (edit) a revision | `jj edit <rev>` | `git checkout <sha>` |
| New change on top of revision | `jj new <rev>` | `git checkout -b <branch> <sha>` |
| Go back to previous change | `jj edit @-` | `git checkout HEAD^` |
| Find commits by message | `jj log -r 'description(glob:"*foo*")'` | `git log --grep=foo` |

Useful revsets:
- `@` — working copy
- `@-` — parent of working copy
- `main` — the main bookmark
- `heads(::@- & bookmarks())` — nearest ancestor bookmark (used by `tug`)
- `..@` — all ancestors of working copy not in `main`

### Workspaces (not worktrees)

| Task | jj command | git equivalent |
|------|-----------|----------------|
| Add workspace | `jj workspace add <path> --name <name>` | `git worktree add <path>` |
| List workspaces | `jj workspace list` | `git worktree list` |
| Remove workspace | `jj workspace forget <name>` | `git worktree remove` |

**Note**: Use `jj workspace add`, never `git worktree add` — even in colocated repos.
No `.gitignore` entry is needed for jj workspaces.

### Conflict Resolution

jj tracks conflicts as first-class objects — a conflicted commit can be committed and rebased
without resolving immediately.

| Task | jj command |
|------|-----------|
| Check if conflicts exist | `jj status` (look for "Conflict" marker) |
| Resolve conflicts interactively | `jj resolve` (opens diff editor) |
| Resolve specific file | `jj resolve <path>` |
| Abandon a conflicted rebase | `jj abandon` |

## Workflow Patterns

### Typical feature branch workflow

```bash
# Start from main
jj new main

# Make changes, then describe them
jj describe -m "feat: add user authentication"

# Create a bookmark for the PR
jj bookmark create feat/auth

# Push to remote
jj git push -b feat/auth --allow-new
```

### Amending a commit mid-stack

```bash
# Navigate to the commit to change
jj edit <rev>

# Make file edits — they automatically become part of that commit

# Return to working copy
jj new
```

### Viewing what will be pushed

```bash
jj log -r "..@ & ~::main"
```

## What NOT to Do in a jj Repo

- **Never** run `git add`, `git commit`, `git branch`, `git worktree` — use jj equivalents
- **Never** run `git checkout` to switch context — use `jj edit` or `jj new`
- **Never** add `--no-gpg-sign` or `--no-verify` flags — signing is automatic via jj config
- **Never** use `git push --force` — use `jj git push --force-with-lease`
