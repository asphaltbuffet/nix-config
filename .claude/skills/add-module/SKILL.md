---
name: add-module
description: Guide through creating a new home-manager module and wiring it into a role. Use when adding a new tool configuration (e.g., a new CLI tool, editor plugin, or shell integration) to the home-manager setup.
---

# Add Home-Manager Module

Follow these steps to add a new home-manager tool module.

## Step 1: Create the module file

Create `home/modules/<tool>/default.nix`. Use the correct function signature:

```nix
# home/modules/<tool>/default.nix
{
  pkgs,
  lib,
  config,
  ...
}: {
  # your tool configuration here
}
```

Use `{pkgs, ...}:` if you only need packages. Use `{pkgs, lib, config, ...}:` if you need conditionals or option access.

### Example: simple tool

```nix
{pkgs, ...}: {
  programs.<tool> = {
    enable = true;
    # tool-specific options
  };

  home.packages = with pkgs; [
    # any extra packages
  ];
}
```

### Example: tool with config file

```nix
{pkgs, lib, ...}: {
  programs.<tool> = {
    enable = true;
    settings = {
      # structured settings preferred over raw extraConfig
    };
  };
}
```

## Step 2: Wire into the appropriate role

Edit the relevant role in `home/roles/`:

| Role | Use for |
|---|---|
| `home/roles/base.nix` | Shell, prompt, essential CLI tools every user needs |
| `home/roles/dev.nix` | Development tools (editors, LSPs, version managers) |
| `home/roles/admin.nix` | Ops/infra tools (SSH, cloud CLIs, system utilities) |
| `home/roles/player.nix` | Gaming and media tools |

Add the import to the role's `imports` list:

```nix
imports = [
  # ... existing imports ...
  ../modules/<tool>
];
```

**Key convention**: modules are always imported from roles, never directly from `home/users/<name>.nix`.

## Step 3: Track the new file

```bash
jj file track home/modules/<tool>/default.nix
```

**Never use `git add`** — this is a jujutsu repo.

## Step 4: Build to verify

```bash
just build
```

Fix any evaluation errors. Common issues:
- Missing `pkgs` attribute — ensure the function signature includes `pkgs`
- Option not found — check the home-manager option path in `man home-configuration.nix` or nixd LSP
- Unused variable warning from statix — use `_` prefix or `lib.mkIf` guards

## Notes

- Each module directory must be named after the tool and contain `default.nix`
- Prefer `programs.<tool>.settings` (structured) over `programs.<tool>.extraConfig` (raw strings) when available
- For secrets (API keys, tokens), do not inline them — use `op inject` references or environment variables set by the 1Password SSH agent
