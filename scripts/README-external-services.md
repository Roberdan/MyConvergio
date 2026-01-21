# External Services Helper Scripts

**Context Optimization**: These CLI wrappers replace MCP servers, saving **21.4k tokens (10.7%)**.

## Token Savings Breakdown

| MCP Server | Tools | Token Overhead | CLI Alternative |
|------------|-------|----------------|-----------------|
| Grafana    | 91    | 13.8k tokens   | HTTP API + grr  |
| Supabase   | 29    | 5.0k tokens    | supabase CLI    |
| Vercel     | 11    | 2.6k tokens    | vercel CLI      |
| **Total**  | 131   | **21.4k**      | -               |

## Quick Reference

### Grafana (`grafana-helper.sh`)

```bash
# Setup (one-time)
export GRAFANA_API_KEY=glsa_...
export GRAFANA_URL=https://mirrorbuddy.grafana.net

# Common operations
grafana-helper.sh dashboards              # List all dashboards
grafana-helper.sh dashboard <uid>         # Get dashboard
grafana-helper.sh datasources             # List datasources
grafana-helper.sh datasource <uid>        # Get datasource
grafana-helper.sh alerts                  # List alerts
grafana-helper.sh health                  # Health check
```

### Supabase (`supabase-helper.sh`)

Requires: `brew install supabase/tap/supabase`

```bash
# Common operations
supabase-helper.sh projects               # List projects
supabase-helper.sh status                 # Project status
supabase-helper.sh migrate <name>         # Create migration
supabase-helper.sh migrations             # List migrations
supabase-helper.sh db-push                # Push changes
supabase-helper.sh functions              # List edge functions
supabase-helper.sh deploy <function>      # Deploy function
supabase-helper.sh logs <service>         # View logs
```

### Vercel (`vercel-helper.sh`)

Requires: `npm i -g vercel`

```bash
# Common operations
vercel-helper.sh projects                 # List projects
vercel-helper.sh deployments              # List deployments
vercel-helper.sh deploy --prod            # Deploy to production
vercel-helper.sh logs [deployment]        # View logs
vercel-helper.sh env                      # List env vars
vercel-helper.sh domains                  # List domains
vercel-helper.sh status <deployment>      # Deployment status
```

## Installation Check

```bash
# Verify all CLIs are available
command -v supabase && echo "✓ Supabase CLI installed"
command -v vercel && echo "✓ Vercel CLI installed"
command -v grr && echo "○ grr (optional for Grafana)"

# Test helper scripts
grafana-helper.sh help
supabase-helper.sh help
vercel-helper.sh help
```

## Disabling MCP Servers

To free up 21.4k tokens, disable MCP servers in Claude Code:

1. **Via UI**: Settings → MCP Servers → Disable Grafana/Supabase/Vercel
2. **Via Config** (if using config file):

```json
{
  "mcpServers": {
    "grafana": { "disabled": true },
    "supabase": { "disabled": true },
    "vercel": { "disabled": true }
  }
}
```

## Environment Setup

Add to `~/.claude/.env`:

```bash
# Grafana
GRAFANA_URL=https://mirrorbuddy.grafana.net
GRAFANA_API_KEY=glsa_...

# Supabase (configured via supabase CLI)
# Run: supabase link

# Vercel (configured via vercel CLI)
# Run: vercel login
```

## When to Use MCP vs CLI

| Scenario | Recommendation |
|----------|----------------|
| Quick status check | CLI (faster, 0 tokens) |
| Deploy/migrate operations | CLI (official tools) |
| Complex debugging | Consider MCP if context helps |
| Automated scripts | CLI (scriptable) |
| One-off commands | CLI (no overhead) |

## Documentation

- Grafana API: https://grafana.com/docs/grafana/latest/developers/http_api/
- Supabase CLI: https://supabase.com/docs/guides/cli
- Vercel CLI: https://vercel.com/docs/cli
