{pkgs, ...}: {
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    # User-level CLAUDE.md: applies globally to every project session.
    # Keep minimal — project-level CLAUDE.md files handle specifics.
    context = ./claude-md.md;

    # ── Skills ────────────────────────────────────────────────────────────
    skills = ./skills;

    # ── MCP servers ─────────────────────────────────────────────────────────
    # Written to .mcp.json (the dedicated MCP config file Claude Code reads).
    # Note: mcpServers inside `settings` maps to settings.json which Claude Code
    # does NOT load MCPs from — always use this top-level option instead.
    #
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

      serena = {
        command = "serena";
        args = [
          "start-mcp-server"
          "--context"
          "claude-code"
          "--project-from-cwd"
        ];
      };
    };

    settings = {
      # ── Plugins ──────────────────────────────────────────────────────────
      enabledPlugins = import ./plugins.nix;

      # ── Behaviour ─────────────────────────────────────────────────────────
      alwaysThinkingEnabled = false;
      effortLevel = "medium";
      model = "opusplan";
      promptSuggestionEnabled = false;
      includeGitInstructions = false;

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

      # ── Hooks ─────────────────────────────────────────────────────────────
      hooks = {
        SessionStart = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "serena-hooks activate --client=claude-code";
              }
            ];
          }
        ];
        PreToolUse = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "serena-hooks remind --client=claude-code";
              }
            ];
          }
          {
            matcher = "mcp__serena__*";
            hooks = [
              {
                type = "command";
                command = "serena-hooks auto-approve --client=claude-code";
              }
            ];
          }
        ];
        Stop = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "serena-hooks cleanup --client=claude-code";
              }
            ];
          }
        ];
      };
    };
  };
}
