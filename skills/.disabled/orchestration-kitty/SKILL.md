---
name: orchestration
description: Parallel execution using multiple Claude instances in Kitty terminal
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Task
context: fork
user-invocable: true
version: "1.0.0"
---

# Multi-Worker Parallel Orchestration Skill

## Overview

Parallel execution of plans using Claude and/or Copilot CLI workers in Kitty terminal tabs. Supports mixed-engine mode where Claude handles complex tasks and Copilot handles mechanical ones.

## When to Use

- Complex tasks with 4+ independent subtasks
- Release preparations with multiple verification steps
- Large refactoring across multiple file domains
- Any plan created by `strategic-planner` agent

## Requirements

| Requirement | Details                                               |
| ----------- | ----------------------------------------------------- |
| Terminal    | **Kitty only** (not Warp/iTerm/Terminal.app)          |
| Config      | `allow_remote_control yes` in kitty.conf              |
| Claude      | `wildClaude='claude --dangerously-skip-permissions'`  |
| Copilot     | `copilot` CLI + `GH_TOKEN` or `COPILOT_TOKEN` env var |
| Max Workers | 4 (hard limit)                                        |

## Quick Start

```bash
# Claude-only (default):
orchestrate.sh <plan> 4

# Copilot-only (all workers use copilot --yolo):
orchestrate.sh <plan> 4 --engine copilot

# Mixed (Claude for complex, Copilot for codex:true tasks):
orchestrate.sh <plan> 4 --engine mixed

# Monitor (detects both Claude-N and Copilot-N tabs):
claude-monitor.sh

# Launch single worker by type:
worker-launch.sh claude "Claude-2" <task_db_id> --cwd /worktree
worker-launch.sh copilot "Copilot-3" <task_db_id> --cwd /worktree

# Standalone Copilot worker (no Kitty needed):
copilot-worker.sh <task_db_id> --model claude-sonnet-4-5 --timeout 600
```

## Integration with Agents

### strategic-planner

The `strategic-planner` agent can create plans with Claude assignments and execute them in parallel:

```
@strategic-planner Create an execution plan for [task] with parallel execution
```

When asked "Vuoi eseguire in parallelo?", it will:

1. Verify Kitty environment
2. Launch Claude workers
3. Send tasks to each worker
4. Monitor progress
5. Report completion

## Plan Format

Plans for parallel execution must include:

```markdown
## 🎭 RUOLI CLAUDE

| Claude   | Role        | Tasks      | Files           |
| -------- | ----------- | ---------- | --------------- |
| CLAUDE 1 | Coordinator | Monitor    | -               |
| CLAUDE 2 | Implementer | T-01, T-02 | src/api/        |
| CLAUDE 3 | Implementer | T-03, T-04 | src/components/ |
| CLAUDE 4 | Implementer | T-05       | src/lib/        |
```

## Critical Rules

1. **NO FILE OVERLAP** - Avoid git conflicts
2. **MAX 4 WORKERS** - Beyond = chaos
3. **VERIFY LAST** - lint/typecheck/build at end
4. **GIT COORDINATION** - One commit at a time
5. **WORKTREE MANDATORY** - Every worker runs `worktree-guard.sh` first. NEVER on main.
6. **COPILOT: --yolo** - Always use `copilot --yolo` for full autonomy (no confirmation prompts)

## Copilot CLI Flags Reference

| Flag               | Purpose                                         |
| ------------------ | ----------------------------------------------- |
| `--yolo`           | Full autonomy, no confirmations (REQUIRED)      |
| `--add-dir <path>` | Trust worktree directory                        |
| `--model <model>`  | Select model (claude-sonnet-4-5, gpt-4.1, etc.) |
| `-p "prompt"`      | Non-interactive mode (for scripted execution)   |

## Scripts

| Script                   | Purpose                                             |
| ------------------------ | --------------------------------------------------- |
| `orchestrate.sh`         | Main orchestrator (--engine claude\|copilot\|mixed) |
| `worker-launch.sh`       | Launch single worker in Kitty tab                   |
| `copilot-worker.sh`      | Standalone Copilot task execution                   |
| `copilot-task-prompt.sh` | Generate Copilot-compatible prompt from DB task     |
| `worktree-guard.sh`      | Block execution if not in correct worktree          |
| `claude-monitor.sh`      | Monitor all worker tabs (Claude + Copilot)          |
| `kitty-check.sh`         | Verify Kitty setup                                  |

## Related

- Agent: `.claude/agents/core_utility/strategic-planner.md`
- Global config: `~/.claude/commands/planner.md`
- Drift check: `plan-db.sh drift-check <plan_id>`
