{...}: {
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
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
        "feature-dev@claude-plugins-official" = false;
        "cli-demo-generator@daymade-skills" = true;
        "skill-creator@daymade-skills" = true;
        "claude-md-management@claude-plugins-official" = true;
        "explanatory-output-style@claude-plugins-official" = true;
        "superpowers@claude-plugins-official" = true;
        "claude-md-progressive-disclosurer@daymade-skills" = true;
        "claude-skills-troubleshooting@daymade-skills" = true;
        "deep-research@daymade-skills" = true;
        "skill-reviewer@daymade-skills" = true;
        "skills-search@daymade-skills" = false;
        "context7@claude-plugins-official" = true;
        "code-review@claude-plugins-official" = true;
        "code-simplifier@claude-plugins-official" = true;
        "claude-code-setup@claude-plugins-official" = true;
        "hookify@claude-plugins-official" = true;
        "atomic-agents@claude-plugins-official" = true;
        "docs-cleaner@daymade-skills" = true;
        "mermaid-tools@daymade-skills" = true;
        "statusline-generator@daymade-skills" = true;
      };

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
        allow = [
          # jj read-only subcommands
          "Bash(jj status*)"
          "Bash(jj log*)"
          "Bash(jj diff*)"
          "Bash(jj show*)"
          "Bash(jj describe --no-edit*)"
          # file search / content search
          "Bash(fd *)"
          "Bash(rg *)"
          # nix inspection (no building or switching)
          "Bash(nix flake show*)"
          "Bash(nix flake check*)"
          "Bash(nix eval *)"
          # just read-only recipes
          "Bash(just build*)"
          "Bash(just check*)"
          "Bash(just fmt*)"
          "Bash(just diff*)"
          "Bash(just hosts*)"
        ];
        # git is explicitly denied — use jj instead
        deny = [
          "Bash(git commit*)"
          "Bash(git push*)"
          "Bash(git reset*)"
          "Bash(git checkout*)"
        ];
      };

      # ── MCP servers ───────────────────────────────────────────────────────
      # The API key is never stored in settings.json. Instead, CONTEXT7_API_KEY
      # is injected into the shell environment via op inject (secrets.env), and
      # Claude Code passes this env block to the MCP child process — so the key
      # stays out of the world-readable Nix store entirely.
      mcpServers = {
        context7 = {
          command = "npx";
          args = ["-y" "@upstash/context7-mcp@latest"];
          env = {
            CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
          };
        };
      };
    };
  };
}
