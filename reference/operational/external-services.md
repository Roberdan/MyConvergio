# External Services (MCP Alternative)

**Context Savings**: Disabling MCP servers saves **21.4k tokens (10.7%)**

| Service | CLI/API | Helper Script | MCP Overhead |
|---------|---------|---------------|--------------|
| Grafana | HTTP API + `grr` | `~/.claude/scripts/grafana-helper.sh` | 13.8k tokens |
| Supabase | `supabase` CLI | `~/.claude/scripts/supabase-helper.sh` | 5.0k tokens |
| Vercel | `vercel` CLI | `~/.claude/scripts/vercel-helper.sh` | 2.6k tokens |

## Usage

```bash
# Grafana operations
grafana-helper.sh dashboards
grafana-helper.sh dashboard <uid>
grafana-helper.sh datasources

# Supabase operations
supabase-helper.sh projects
supabase-helper.sh migrate <name>
supabase-helper.sh deploy <function>

# Vercel operations
vercel-helper.sh deployments
vercel-helper.sh deploy --prod
vercel-helper.sh logs
```

## MCP Configuration

To disable MCP servers and save tokens:

```json
{
  "mcpServers": {
    "grafana": { "disabled": true },
    "supabase": { "disabled": true },
    "vercel": { "disabled": true }
  }
}
```
