# Global plugin enable/disable list for Claude Code.
#
# To override a plugin for a specific project, add an enabledPlugins attrset
# to the project's .claude/settings.json (or settings.local.json):
#
#   { "enabledPlugins": { "some-plugin@some-registry": false } }
#
# Project-level entries are merged on top of these global defaults.
{
  # ── LSP ────────────────────────────────────────────────────────────────
  "gopls-lsp@claude-plugins-official" = true;

  # ── Workflow / skills ──────────────────────────────────────────────────
  "superpowers@claude-plugins-official" = true;
  "code-review@claude-plugins-official" = true;
  "code-simplifier@claude-plugins-official" = true;
  "claude-md-management@claude-plugins-official" = true;
  "claude-code-setup@claude-plugins-official" = true;
  "hookify@claude-plugins-official" = true;
  "atomic-agents@claude-plugins-official" = true;
  "feature-dev@claude-plugins-official" = false;
  "skill-creator@daymade-skills" = true;
  "skill-reviewer@daymade-skills" = true;
  "skills-search@daymade-skills" = false;
  "deep-research@daymade-skills" = true;
  "claude-md-progressive-disclosurer@daymade-skills" = true;
  "claude-skills-troubleshooting@daymade-skills" = true;
  "cli-demo-generator@daymade-skills" = true;
  "docs-cleaner@daymade-skills" = true;
  "mermaid-tools@daymade-skills" = true;
  "statusline-generator@daymade-skills" = true;

  # ── Context / data ─────────────────────────────────────────────────────
  "context7@claude-plugins-official" = true;

  # ── Output style ───────────────────────────────────────────────────────
  "explanatory-output-style@claude-plugins-official" = true;
}
