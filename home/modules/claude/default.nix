{
  pkgs,
  inputs,
  ...
}: {
  programs.claude-code = {
    enable = true;

    # User-level CLAUDE.md: applies globally to every project session.
    # Keep minimal — project-level CLAUDE.md files handle specifics.
    memory.source = ./claude-md.md;

    # ── Skills ────────────────────────────────────────────────────────────
    skillsDir = ./skills;

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
        # the serena version and the project is always set correctly.
        serena = {
          command = "${inputs.serena.packages.${pkgs.stdenv.hostPlatform.system}.serena}/bin/serena";
          args = [
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
