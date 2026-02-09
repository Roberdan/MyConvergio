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
├── PLANNER-ARCHITECTURE.md # SQLite DB schema and authority rules
├── server.sh              # PM2 server management (start/stop/restart)
├── data/
│   └── dashboard.db       # SQLite database (WAL mode)
├── dashboard/             # Web dashboard + API
│   ├── server.js          # API server (port 31415)
│   ├── reboot.js          # Server restart script
│   ├── ecosystem.config.js # PM2 configuration
│   └── server/            # API routes
├── docs/
│   └── adr/               # Architecture Decision Records (0001-0006)
├── rules/                 # Compact rules (loaded on every session)
│   ├── coding-standards.md # Code style rules
│   └── guardian.md        # Process + Thor enforcement
├── reference/             # NOT auto-loaded (saves ~19k tokens)
│   ├── operational/       # Quick guides (worktree, execution, memory)
│   └── detailed/          # Full rules for on-demand reference
├── scripts/               # CLI utilities (30+ scripts)
│   ├── plan-db.sh         # Plan/wave/task management (central CLI)
│   ├── plan-db-safe.sh    # Safe wrapper with pre-checks
│   ├── lib/               # plan-db modules (8 libraries)
│   ├── *-digest.sh        # Token-efficient command wrappers
│   ├── file-lock.sh       # File-level locking (concurrency)
│   ├── stale-check.sh     # Stale context detection (concurrency)
│   ├── wave-overlap.sh    # Intra-wave overlap check (concurrency)
│   ├── merge-queue.sh     # Sequential merge queue (concurrency)
│   └── session-cleanup.sh # Idle process cleanup (stability)
├── commands/              # Skill definitions (/prompt, /planner, /execute, etc.)
├── agents/                # Local agent definitions
│   └── technical_development/ # task-executor, adversarial-debugger
└── copilot-agents/        # Copilot agent definitions
```

## Configuration Notes

- **MCP source of truth (Claude Code)**: `~/.claude/mcp.json`. Desktop config mirrors this file.
- **Dashboard DB**: Single source of truth is `~/.claude/data/dashboard.db`.
- **Token tracking API**: Uses `DASHBOARD_API` if set, default `http://127.0.0.1:31415/api/tokens`.

## Dashboard

Real-time plan monitoring, SSE notifications, tree navigation, token tracking.

```bash
cd ~/.claude/dashboard && node reboot.js   # Restart
pm2 status                                 # Check PM2 status
curl http://localhost:31415/api/health     # Health check
```

Key endpoints: `GET /api/health`, `GET /api/plans`, `POST /api/tokens`, `GET /api/tokens/summary/:plan_id`, `GET /api/notifications/stream`.

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

### Concurrency Control

Prevents parallel agents from overwriting each other's work. See [ADR-0005](docs/adr/0005-multi-agent-concurrency-control.md).

```bash
# File-level locking
plan-db.sh lock acquire <file> <task_id> [--agent NAME] [--timeout N]
plan-db.sh lock release <file>
plan-db.sh lock release-task <task_id>    # Release all locks for a task
plan-db.sh lock check <file>              # Who holds the lock?
plan-db.sh lock list                      # All active locks

# Stale context detection
plan-db.sh stale-check snapshot <task_id> <file1> [file2...]
plan-db.sh stale-check check <task_id>    # Returns stale:true/false
plan-db.sh stale-check diff <task_id>     # Show changed files

# Wave overlap detection (run before importing spec)
plan-db.sh wave-overlap check-spec <spec.json>

# Merge queue (sequential merge with validation)
plan-db.sh merge-queue enqueue <branch> [--priority N] [--worktree PATH]
plan-db.sh merge-queue process [--validate] [--dry-run]
plan-db.sh merge-queue status
```

### Digest Scripts

Compact JSON wrappers replacing verbose CLI commands. See [ADR-0001](docs/adr/0001-digest-scripts-token-optimization.md).

```bash
git-digest.sh [--full]                # git status + log in ONE call
service-digest.sh ci|pr|deploy|all    # CI/PR/Deploy status
test-digest.sh                        # Compact test output
build-digest.sh                       # Compact build output
diff-digest.sh main feat              # Compact diff
```

### System Stability

See [ADR-0006](docs/adr/0006-system-stability-crash-prevention.md).

```bash
session-cleanup.sh [--dry-run] [--max-idle MINUTES]  # Kill idle sessions
mdatp exclusion list                                  # Verify Defender config
```

## Workflow

### 1. Prompt Translation (`/prompt`)

- Extract F-xx requirements from user request
- User confirms requirements list

### 2. Planning (`/planner`)

- Create plan with waves and tasks
- Run `wave-overlap check-spec` to detect file conflicts
- Link F-xx to tasks, user approves plan

### 3. Execution

- Acquire file locks + snapshot file hashes (Phase 0.5)
- TDD: write tests (RED), implement (GREEN), verify
- Check staleness before commit (Phase 4.7)
- Complete via `plan-db-safe.sh` (auto-releases locks)
- Merge via `merge-queue` (not direct git merge)

### 4. Thor Verification

- Validate per wave (F-xx + code quality)
- Post-merge validation on main
- Build + lint + typecheck must pass

### 5. Closure

- Knowledge codification (ADR, CHANGELOG, running notes)
- User accepts delivery

## Context Optimization

### Token Usage

| File        | Lines   | Purpose                      |
| ----------- | ------- | ---------------------------- |
| CLAUDE.md   | 47      | Core config, quick reference |
| rules/\*.md | 162     | Essential behavior rules     |
| **TOTAL**   | **209** | ~65% reduction from original |

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
sqlite3 ~/.claude/data/dashboard.db ".tables"               # Check DB
rm ~/.claude/data/dashboard.db && plan-db.sh init            # Reinitialize (DESTRUCTIVE)
```

### PM2 issues

```bash
pm2 kill && pm2 start ~/.claude/dashboard/ecosystem.config.js && pm2 save
```

## Version

Last updated: 09 Febbraio 2026
