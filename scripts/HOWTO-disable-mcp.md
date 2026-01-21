# How to Disable MCP Servers in Claude Code

**Goal**: Free up 21.4k tokens (10.7% context) by disabling Grafana, Supabase, and Vercel MCP servers.

## Method 1: Via Claude Code UI (Recommended)

1. Open Claude Code settings:
   ```bash
   claude --settings
   # OR in interactive session: /settings
   ```

2. Navigate to **MCP Servers** section

3. Find and disable:
   - ✓ Grafana (13.8k tokens saved)
   - ✓ Supabase (5.0k tokens saved)
   - ✓ Vercel (2.6k tokens saved)

4. Restart Claude Code session

## Method 2: Edit MCP Config File

MCP configuration is typically in one of these locations:

```bash
# Check these paths
~/.config/claude-code/mcp.json
~/.claude-code/mcp.json
~/Library/Application Support/Claude/mcp.json
```

Add `"disabled": true` to each server:

```json
{
  "mcpServers": {
    "grafana": {
      "command": "...",
      "args": [...],
      "disabled": true
    },
    "supabase": {
      "command": "...",
      "args": [...],
      "disabled": true
    },
    "vercel": {
      "command": "...",
      "args": [...],
      "disabled": true
    }
  }
}
```

## Verification

After disabling, check context usage:

```bash
claude
# In session: /context
```

Expected result:
- **Before**: MCP tools ~21.4k tokens
- **After**: MCP tools ~0 tokens (or only remaining servers)

## Alternative CLI Workflows

Once disabled, use CLI helper scripts instead:

```bash
# Grafana
grafana dashboards
grafana dashboard <uid>

# Supabase
supabase-wrap projects
supabase-wrap migrate <name>

# Vercel
vercel-wrap deployments
vercel-wrap deploy --prod
```

See: `~/.claude/scripts/README-external-services.md` for full reference.

## Rollback

To re-enable MCP servers:
1. Remove `"disabled": true` from config
2. Or toggle back on in Claude Code UI
3. Restart session

## Benefits

- **21.4k tokens freed** (10.7% of 200k budget)
- Faster session startup (no MCP initialization)
- Direct CLI access (more scriptable)
- Zero token overhead for operations
