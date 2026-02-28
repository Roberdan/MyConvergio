# ADR 0017: CodeGraph MCP-Only, No CLI

Status: Accepted | Date: 21 Feb 2026

## Context

CodeGraph is a semantic code analysis tool that builds graph representations of codebases (AST, call graphs, dependency graphs). Two integration approaches exist:

1. **CLI mode**: Shell scripts invoke `codegraph` binary, parse JSON output
2. **MCP mode**: MCP server exposes tools (`codegraph_search`, `codegraph_context`, `codegraph_symbols`)

CLI mode introduces complexity: spawning processes, parsing JSON, error handling, fallback logic. MCP mode provides native tool integration with structured outputs and error handling built into the MCP protocol.

Early implementations used hybrid approaches (MCP with CLI fallback), adding conditional logic throughout digest scripts and agent workflows.

## Decision

**CodeGraph uses MCP tools exclusively. No CLI fallback.**

### Requirements

**MCP Server Running:**
- CodeGraph MCP server must be configured in `mcp.json` or `claude_desktop_config.json`
- Server provides tools: `codegraph_search`, `codegraph_context`, `codegraph_symbols`, `codegraph_definitions`, `codegraph_references`

**Directory Structure:**
- Repository must have `.codegraph/` directory with indexed data
- Indexing: `codegraph index <repo_path>` (run once, or via pre-commit hook)
- Staleness: Re-index when significant code changes occur (>10% files modified)

**Tool Usage:**
- Agents call MCP tools directly (no shell script wrappers)
- Tools return structured JSON via MCP protocol
- Errors (missing index, stale data) propagate as MCP tool errors

### MCP Tool Catalog

| Tool                        | Purpose                                  | Returns                         |
|-----------------------------|------------------------------------------|---------------------------------|
| `codegraph_search`          | Semantic code search                     | Ranked list of code locations   |
| `codegraph_context`         | Get context around symbol/function       | Call graph, dependencies        |
| `codegraph_symbols`         | List symbols in file/module              | Symbol names, types, locations  |
| `codegraph_definitions`     | Find symbol definitions                  | Definition locations            |
| `codegraph_references`      | Find symbol references                   | Reference locations             |

### Error Handling

**Missing `.codegraph/` directory:**
- Tool returns error: `CodeGraph index not found. Run: codegraph index <repo_path>`
- Agent prompts user to initialize CodeGraph or skips semantic analysis

**Stale Index:**
- Tool returns warning: `Index is X days old. Consider re-indexing.`
- Agent continues with stale data (better than no data)

**MCP Server Not Running:**
- Tool invocation fails with MCP error: `Tool not available`
- Agent falls back to grep/ripgrep for basic search (degraded mode)

### Migration from CLI/Hybrid

**Remove:**
- All `codegraph` CLI invocations in shell scripts
- JSON parsing logic for CLI output
- Conditional logic checking for CLI binary existence

**Keep:**
- `.codegraph/` directory and index files
- `codegraph index` CLI command (for indexing only, not analysis)

**Update:**
- Digest scripts: replace CLI calls with MCP tool invocations
- Agent workflows: use MCP tools instead of delegating to shell scripts
- Documentation: remove CLI references, update with MCP tool examples

## Consequences

- **Positive**: Simpler integration (no process spawning, JSON parsing). Native MCP error handling. Consistent tool interface across all agents. Eliminates hybrid mode complexity. MCP protocol handles retries, timeouts, streaming.
- **Negative**: Hard dependency on MCP server (no offline mode). Requires `.codegraph/` index (manual setup). Agents cannot analyze un-indexed repositories. Initial indexing can take 30-120 seconds on large repos.

## Enforcement

- Rule: Agents must NOT invoke `codegraph` CLI binary directly (except for `codegraph index`)
- Check: `grep -r "codegraph [^i]" scripts/` should return zero results (only `codegraph index` allowed)
- Check: MCP server presence: `jq '.mcpServers.codegraph' < mcp.json` (must exist)
- Migration: Remove all CLI fallback logic from existing scripts

## File Impact

| File                                   | Change                                                |
|----------------------------------------|-------------------------------------------------------|
| `scripts/git-digest.sh`                | Remove CLI codegraph calls, use MCP tools             |
| `scripts/file-digest.sh`               | Remove CLI codegraph calls, use MCP tools             |
| `agents/*/system-prompt.md`            | Update CodeGraph usage examples (MCP only)            |
| `mcp.json`                             | Ensure codegraph server configured                    |
| `claude_desktop_config.json`           | Ensure codegraph server configured (alternative)      |
| `.codegraph/config.json`               | CodeGraph index configuration                         |
| `reference/tools/codegraph.md`         | New — MCP tool usage reference documentation          |
| `docs/setup/codegraph-setup.md`        | New — Indexing and MCP server setup guide             |

## Setup Instructions

### 1. Index Repository

```bash
codegraph index /path/to/repo
```

Creates `.codegraph/` directory with indexed data.

### 2. Configure MCP Server

Add to `mcp.json`:

```json
{
  "mcpServers": {
    "codegraph": {
      "command": "codegraph-server",
      "args": ["--repo", "/path/to/repo"]
    }
  }
}
```

### 3. Verify Tools Available

In Claude Code or Copilot CLI:

```
Available tools: codegraph_search, codegraph_context, ...
```

### 4. Usage Example

```
Agent: Use codegraph_search to find authentication logic
→ MCP server returns ranked results
→ Agent analyzes results
```

## Related ADRs

- ADR-0001: Digest Scripts Token Optimization (semantic search use case)
- ADR-0009: Compact Markdown Format (tool output format)
