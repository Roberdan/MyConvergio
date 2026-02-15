<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# External Services (MCP Alternative)

**Context Savings**: Disabling MCP servers saves **21.4k tokens (10.7%)**

| Service  | CLI/API          | Helper Script        | MCP Overhead |
| -------- | ---------------- | -------------------- | ------------ |
| Grafana  | HTTP API + `grr` | `grafana-helper.sh`  | 13.8k tokens |
| Supabase | `supabase` CLI   | `supabase-helper.sh` | 5.0k tokens  |
| Vercel   | `vercel` CLI     | `vercel-helper.sh`   | 2.6k tokens  |

## Usage

```bash
# Grafana
grafana-helper.sh dashboards
grafana-helper.sh dashboard <uid>
grafana-helper.sh datasources

# Supabase
supabase-helper.sh projects
supabase-helper.sh migrate <name>
supabase-helper.sh deploy <function>

# Vercel
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
