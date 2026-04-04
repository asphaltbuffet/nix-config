# User-Level Conventions

- Development work lives in `~/dev/`
- VCS is **jujutsu** (`jj`). Do not use `git` commands directly.
- **Token economy is important**: be concise, avoid re-reading files unnecessarily, and do not summarize what you just did.

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

