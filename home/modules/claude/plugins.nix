# Global plugin enable/disable list for Claude Code.
#
# To override a plugin for a specific project, add an enabledPlugins attrset
# to the project's .claude/settings.json (or settings.local.json):
#
#   { "enabledPlugins": { "some-plugin@some-registry": false } }
#
# Project-level entries are merged on top of these global defaults.
{
  # ── LSP / codebase navigation ──────────────────────────────────────────
  "gopls-lsp@claude-plugins-official" = true;

  # ── Workflow / skills ──────────────────────────────────────────────────
  "superpowers@claude-plugins-official" = false;
  "code-review@claude-plugins-official" = true;
  "code-simplifier@claude-plugins-official" = false;
  "claude-md-management@claude-plugins-official" = true;
  "claude-code-setup@claude-plugins-official" = false;
  "hookify@claude-plugins-official" = false;
  "deep-research@daymade-skills" = false;

  # ── Output style ───────────────────────────────────────────────────────
  "explanatory-output-style@claude-plugins-official" = true;
}
