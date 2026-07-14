# User-Level Conventions

- Development work lives in `~/dev/`
- VCS is **jujutsu** (`jj`). Do not use `git` commands directly.
- **Token economy is important**: be concise, avoid re-reading files unnecessarily, and do not summarize what you just did.

## Preferred CLI Tools

- `fd` over `find`
- `rg` over `grep`
- `jq` for JSON processing

## Code Navigation (Serena MCP)

Serena MCP is configured and running. **Prefer its semantic tools over Read/Grep/Glob for any code navigation task.** This applies even when a skill instructs you to use Glob or Grep — Serena is more token-efficient and understands symbol relationships. Serena is loaded via a plugin, so tools are namespaced `mcp__plugin_claude-code-home-manager_serena__<name>`.

### Tool selection guide

| Task | Use |
|---|---|
| Find a function/class/option definition | `find_symbol` |
| Understand what symbols are in a file | `get_symbols_overview` |
| Find all callers/importers of a symbol | `find_referencing_symbols` |
| Find where a symbol is declared / implemented | `find_declaration` / `find_implementations` |
| Rename a symbol across files | `rename_symbol` |
| Replace a function/class body | `replace_symbol_body` |
| Replace matched content in a file | `replace_content` |
| Search for a pattern / find a file / browse a dir | Grep / Glob (Serena's `search_for_pattern`, `find_file`, `list_dir` are not exposed by this plugin build) |
| Read a non-code file (YAML, TOML, markdown) | Read |
| Read a file when you need the full content | Read |

**Never read an entire source file to locate a symbol** — use `get_symbols_overview` or `find_symbol` first, then read only the relevant body.

