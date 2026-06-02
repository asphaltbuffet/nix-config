{
  pkgs,
  lib,
  ...
}: {
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
      model = "sonnet";
      promptSuggestionEnabled = false;
      includeGitInstructions = false;
      skillListingBudgetFraction = 0.03;
      feedbackSurveyRate = 0;

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

  # Before home-manager's writeBoundary runs, rotate any existing .hm-bak to a
  # timestamped name so the backup slot is free for this switch. This preserves
  # prior backups (useful for recovering settings) while preventing the
  # "would be clobbered" error on repeated switches.
  home.activation.rotateClaudeSettingsBackup = lib.hm.dag.entryBefore ["writeBoundary"] ''
    bak="$HOME/.claude/settings.json.hm-bak"
    if [ -f "$bak" ]; then
      mv "$bak" "$bak.$(date +%Y%m%d-%H%M%S)"
    fi
  '';

  # Replace the Nix store symlink for settings.json with a writable copy so
  # Claude Code can write permission allows during a session. The next
  # home-manager switch will back up the mutated file as settings.json.hm-bak
  # (via home-manager.backupFileExtension = "hm-bak") before restoring the
  # baseline symlink, which this script then copies again.
  home.activation.makeClaudeSettingsMutable = lib.hm.dag.entryAfter ["writeBoundary"] ''
    settings="$HOME/.claude/settings.json"
    if [ -L "$settings" ]; then
      store_path=$(readlink -f "$settings")
      rm "$settings"
      cp "$store_path" "$settings"
      chmod 644 "$settings"
    fi
  '';
}
