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
        # codebase navigation). Registered here so Nix controls the uv version
        # rather than the plugin's uvx invocation. The serena plugin remains
        # enabled for its project scaffolding and tool descriptions.
        serena = {
          command = "${pkgs.uv}/bin/uvx";
          args = [
            "--from"
            "git+https://github.com/oraios/serena"
            "serena"
            "start-mcp-server"
            "--context"
            "claude-code"
            "--project-from-cwd"
          ];
          env = {
            ENABLE_TOOL_SEARCH = true;
          };
        };
      };
    };
  };
}
