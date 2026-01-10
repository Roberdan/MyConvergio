# ~/.claude - Claude Global Configuration

Personal Claude Code configuration with dashboard, scripts, and rules.

## Quick Start

```bash
# Server management (PM2)
~/.claude/server.sh start     # Start dashboard
~/.claude/server.sh stop      # Stop dashboard
~/.claude/server.sh restart   # Restart dashboard
~/.claude/server.sh status    # Check status
~/.claude/server.sh logs      # View logs

# Check health
curl http://localhost:31415/api/health

# View in browser
open http://localhost:31415
```

## Structure

```
~/.claude/
├── CLAUDE.md              # Main config (loaded on every session)
├── README.md              # This file
├── server.sh              # PM2 server management (start/stop/restart)
├── data/
│   └── dashboard.db       # SQLite database
├── dashboard/             # Web dashboard
│   ├── server.js          # API server
│   ├── reboot.js          # Server restart script
│   ├── ecosystem.config.js # PM2 configuration
│   ├── js/                # Frontend JavaScript
│   ├── css/               # Styles
│   └── server/            # API routes
├── rules/                 # Compact rules (loaded on every session)
│   ├── execution.md       # Execution & quality rules
│   ├── guardian.md        # Thor enforcement
│   ├── agent-discovery.md # Agent routing
│   ├── engineering-standards.md
│   └── file-size-limits.md
├── reference/             # NOT auto-loaded (saves ~19k tokens)
│   └── detailed/          # Full rules for on-demand reference
├── scripts/               # CLI utilities
│   ├── plan-db.sh         # Plan/wave/task management
│   └── register-project.sh
├── commands/              # Skill definitions
│   ├── prompt.md          # /prompt skill
│   └── planner.md         # /planner skill
└── agents/                # Local agent definitions
```

## Configuration Notes

- **MCP source of truth (Claude Code)**: `~/.claude/mcp.json`. Desktop config mirrors this file.
- **Dashboard DB**: Single source of truth is `~/.claude/data/dashboard.db`.
- **Token tracking API**: Uses `DASHBOARD_API` if set, default `http://127.0.0.1:31415/api/tokens`.

## Dashboard

### Features
- Real-time plan monitoring
- SSE notifications (no polling)
- Notification dropdown preview
- Configurable notification triggers
- Tree navigation (waves → tasks)
- Health endpoint monitoring

### API Endpoints
| Endpoint | Description |
|----------|-------------|
| GET /api/health | Server health + DB status |
| GET /api/projects | List all projects |
| GET /api/plans | List plans |
| GET /api/notifications/stream | SSE real-time notifications |
| GET /api/notifications/triggers | List trigger configs |
| POST /api/notifications/triggers/:id/toggle | Toggle trigger |

### Management
```bash
# Restart server
cd ~/.claude/dashboard && node reboot.js

# With PM2 (recommended)
pm2 status                    # Check status
pm2 logs claude-dashboard     # View logs
pm2 restart claude-dashboard  # Restart
pm2 stop claude-dashboard     # Stop

# Without PM2
node reboot.js --no-pm2
```

## Scripts

### server.sh - Dashboard Server
```bash
~/.claude/server.sh start     # Start with PM2, prints URL
~/.claude/server.sh stop      # Stop server
~/.claude/server.sh restart   # Restart, prints URL
~/.claude/server.sh status    # PM2 status
~/.claude/server.sh logs      # Last 50 log lines
```

### plan-db.sh - Plan Management
```bash
# Create plan
~/.claude/scripts/plan-db.sh create {project_id} "Plan Name"

# Add wave
~/.claude/scripts/plan-db.sh add-wave {plan_id} "W1" "Phase Name"

# Add task
~/.claude/scripts/plan-db.sh add-task {wave_id} T1-01 "Task Name" P1 feature

# Update task
~/.claude/scripts/plan-db.sh update-task {task_id} in_progress
~/.claude/scripts/plan-db.sh update-task {task_id} done "Completion notes"

# Validate
~/.claude/scripts/plan-db.sh validate {plan_id}
~/.claude/scripts/plan-db.sh validate-fxx {plan_id}
```

### register-project.sh - Project Registration
```bash
~/.claude/scripts/register-project.sh "$(pwd)" --name "Project Name"
```

### cleanup-cache.sh - Cache/Log Pruning
```bash
# Remove logs/cache files older than 30 days
~/.claude/scripts/cleanup-cache.sh
```

## Workflow

### 1. Prompt Translation (`/prompt`)
- Extract F-xx requirements from user request
- User confirms requirements list

### 2. Planning (`/planner`)
- Create plan with waves and tasks
- Link F-xx to tasks
- User approves plan

### 3. Execution
- Execute each task
- Update status in DB
- Verify F-xx criteria

### 4. Thor Verification
- Validate per wave
- Build must pass
- All F-xx verified

### 5. Closure
- User accepts delivery

## Context Optimization

### Token Usage
| File | Lines | Purpose |
|------|-------|---------|
| CLAUDE.md | 47 | Core config, quick reference |
| rules/*.md | 162 | Essential behavior rules |
| **TOTAL** | **209** | ~65% reduction from original |

### Detailed Rules
Full versions in `reference/detailed/` (not auto-loaded to save context):
- 9 detailed rule files with examples and edge cases
- Access on-demand: `Read ~/.claude/reference/detailed/...`

## Troubleshooting

### Dashboard won't start
```bash
# Check what's on port
lsof -i:31415

# Force kill and restart
lsof -ti:31415 | xargs kill -9
cd ~/.claude/dashboard && node reboot.js
```

### Database issues
```bash
# Check DB
sqlite3 ~/.claude/data/dashboard.db ".tables"
sqlite3 ~/.claude/data/dashboard.db "SELECT COUNT(*) FROM projects"

# Reinitialize (DESTRUCTIVE)
rm ~/.claude/data/dashboard.db
~/.claude/scripts/plan-db.sh init
```

### PM2 issues
```bash
# Reinstall PM2
npm install -g pm2

# Clear PM2 state
pm2 kill
pm2 start ~/.claude/dashboard/ecosystem.config.js
pm2 save
```

## Version
Last updated: 06 Gennaio 2026
