{pkgs, ...}: {
  programs.claude-code = {
    enable = true;

    # User-level CLAUDE.md: applies globally to every project session.
    # Keep minimal — project-level CLAUDE.md files handle specifics.
    memory.text = ''
      # User-Level Conventions

      - Development work lives in `~/dev/`
      - VCS is **jujutsu** (`jj`). Do not use `git` commands directly.
      - **Token economy is important**: be concise, avoid re-reading files
        unnecessarily, and do not summarize what you just did.

      ## Preferred CLI Tools

      - `fd` over `find`
      - `rg` over `grep`
      - `sd` over `sed` (for in-place substitution)
      - `jq` for JSON processing

      ## Code Navigation (Serena MCP)

      Serena MCP is configured and running. **Prefer its semantic tools over Read/Grep/Glob for any code navigation task.** This applies even when a skill instructs you to use Glob or Grep — Serena is more token-efficient and understands symbol relationships.

      ### Tool selection guide

      | Task | Use |
      |---|---|
      | Find a function/class/option definition | `mcp__serena__find_symbol` |
      | Understand what symbols are in a file | `mcp__serena__get_symbols_overview` |
      | Find all callers/importers of a symbol | `mcp__serena__find_referencing_symbols` |
      | Search for a pattern across the codebase | `mcp__serena__search_for_pattern` |
      | Browse a directory | `mcp__serena__list_dir` |
      | Find a file by name | `mcp__serena__find_file` |
      | Rename a symbol across files | `mcp__serena__rename_symbol` |
      | Replace a function/class body | `mcp__serena__replace_symbol_body` |
      | Read a non-code file (YAML, TOML, markdown) | Read |
      | Read a file when you need the full content | Read |

      **Never read an entire source file to locate a symbol** — use `get_symbols_overview` or `find_symbol` first, then read only the relevant body.

      At session start, call `mcp__serena__check_onboarding_performed` to verify the project is indexed.
    '';

    settings = {
      # ── Plugins ──────────────────────────────────────────────────────────
      enabledPlugins = import ./plugins.nix;

      # ── Behaviour ─────────────────────────────────────────────────────────
      alwaysThinkingEnabled = false;
      effortLevel = "medium";
      promptSuggestionEnabled = false;

      # ── Permissions ───────────────────────────────────────────────────────
      # Only read-only commands are pre-approved here. Commands that make
      # changes (jj commit, nix switch, etc.) should be approved per-project
      # or confirmed interactively.
      permissions = {
        defaultMode = "default";
        allow = import ./permissions_allow.nix;
        deny = import ./permissions_deny.nix;
      };

      # ── Status line ───────────────────────────────────────────────────────
      statusLine = import ./statusline.nix pkgs;

      # ── MCP servers ───────────────────────────────────────────────────────
      # CONTEXT7_API_KEY is loaded by `load-secrets` in zsh at shell startup
      # before Claude Code launches, so it is already in the environment when
      # the MCP child process is spawned.
      # "$VAR" interpolation in MCP env blocks is the standard Claude Code
      # pattern; shell command substitution ($(…)) is not supported there.
      mcpServers = {
        context7 = {
          command = "npx";
          args = ["-y" "@upstash/context7-mcp@latest"];
          env = {
            CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
          };
        };

        # Serena: semantic code analysis via LSP (symbol search, refactoring,
        # codebase navigation). Registered here with --project so Nix controls
        # the uv version and the project is always set correctly.
        # The serena plugin is disabled in plugins.nix to avoid a duplicate
        # MCP server without project context.
        serena = {
          command = "${pkgs.uv}/bin/uvx";
          args = [
            "--from"
            "git+https://github.com/oraios/serena"
            "serena"
            "start-mcp-server"
            "--context"
            "claude-code"
            "--project"
            "."
          ];
          env = {
            ENABLE_TOOL_SEARCH = true;
          };
        };
      };
    };
  };
}
