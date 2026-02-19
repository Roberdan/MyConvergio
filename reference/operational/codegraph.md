<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# CodeGraph

CodeGraph builds semantic knowledge graph for faster code exploration.

**NEVER add `codegraph` CLI hooks to settings.json.** There is NO `codegraph` binary installed. CodeGraph runs ONLY as MCP server (via mcp.json + npx). Do NOT add `codegraph mark-dirty`, `codegraph sync-if-dirty`, or any `codegraph` CLI command anywhere in hooks, scripts, or settings.

## If `.codegraph/` exists in the project

**Use codegraph tools for faster exploration.** These tools provide instant lookups via the code graph instead of scanning files:

| Tool                | Use For                                          |
| ------------------- | ------------------------------------------------ |
| `codegraph_search`  | Find symbols by name (functions, classes, types) |
| `codegraph_context` | Get relevant code context for a task             |
| `codegraph_callers` | Find what calls a function                       |
| `codegraph_callees` | Find what a function calls                       |
| `codegraph_impact`  | See what's affected by changing a symbol         |
| `codegraph_node`    | Get details + source code for a symbol           |

**When spawning Explore agents in a codegraph-enabled project:**

Tell the Explore agent to use codegraph tools for faster exploration.

**For quick lookups in the main session:**

- Use `codegraph_search` instead of grep for finding symbols
- Use `codegraph_callers`/`codegraph_callees` to trace code flow
- Use `codegraph_impact` before making changes to see what's affected

## If `.codegraph/` does NOT exist

Skip codegraph. Use Glob/Grep/Read instead. Do NOT suggest running `codegraph init` — there is no CLI binary.
