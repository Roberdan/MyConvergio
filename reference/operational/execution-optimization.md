<!-- v2.3.0 | 27 Feb 2026 | Rebase-before-merge in wave merge flow -->

# Execution Optimization

## Context Isolation (50-70% Token Reduction)

**Isolated Subagents** (FRESH session per invocation):

- `task-executor` (v1.8.0): NO parent context, TDD workflow, modular
- `thor-quality-assurance-guardian` (v3.3.0): Skeptical validation, Gate 8 TDD, modular

**Benefits**:

- Task executor: ~30K tokens/task (vs 50-100K with inherited context)
- Thor: Unbiased validation (no assumptions from parent session)
- Parallel execution: No context collision between concurrent tasks

**MCP Restrictions**:

- `task-executor`: disables WebSearch/WebFetch (uses Read/Grep only)
- Focus on codebase operations, not web research during execution

## Token Tracking via API (MANDATORY for task-executor)

```bash
curl -s -X POST http://127.0.0.1:31415/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"project_id":"{project}","plan_id":{plan},"wave_id":"{wave}","task_id":"{task}","agent":"task-executor","model":"{model}","input_tokens":{in},"output_tokens":{out},"cost_usd":{cost}}'
```

## Model Escalation Strategy

| Agent Type                 | Default       | Escalation Rule                          |
| -------------------------- | ------------- | ---------------------------------------- |
| Task Executor              | GPT-5.3-Codex | → opus if cross-cutting or architectural |
| Coordinator (Standard)     | sonnet        | → opus if >3 concurrent tasks            |
| Coordinator (Max Parallel) | **opus**      | Required for unlimited parallelization   |
| Coordinator (Agent Teams)  | sonnet        | → opus for large team coordination       |
| Validator (Thor)           | opus          | No escalation                            |

## Parallelization Modes (User Choice)

**Standard Mode** (default):

- Max 3 concurrent task-executors
- Sonnet coordination
- Cost: $ moderate, Speed: normal

**Max Parallel Mode** (optional):

- Max 5 concurrent task-executors (hard cap, was unlimited)
- **Opus coordination** (required)
- Cost: $$$ high, Speed: fast (3-5x)
- Use case: Urgent deadlines, large plans (10+ tasks)
- **36GB RAM machine**: Never exceed 5 parallel. Each executor+subprocess ~800MB-1.5GB

**Agent Teams Mode** (v2.1.x):

- Native multi-agent via `TeamCreate`/`SendMessage`
- Built-in task tracking, message passing, shutdown
- No external terminal dependency
- Cost: $$ moderate, Speed: fast

**Selection**: Planner asks user after plan approval, before execution starts.

## Pre-Spawn Memory Gate (MANDATORY)

Before launching ANY batch of task-executors, coordinator MUST run:

```bash
session-reaper.sh --pre-spawn
```

This: (1) kills orphans older than 1 min, (2) checks swap. If swap > 10GB → **exit 1, BLOCKED**. Coordinator must wait or reduce parallelism. Launchd periodic reaper runs every 120s as safety net.

## Coordinator Post-Task Protocol (MANDATORY)

After each task-executor completes, the coordinator MUST:

0. **Reap orphans**: `session-reaper.sh --max-age 0` (kill any orphaned subprocesses immediately)
1. **Verify DB update**: `sqlite3 ~/.claude/data/dashboard.db "SELECT status FROM tasks WHERE id={db_task_id};"` — if not `done`, run `plan-db.sh update-task {db_task_id} done "notes"`
2. **Thor per-task**: `plan-db.sh validate-task {db_task_id} {plan_id}`
3. **If Thor FAILS**: fix issue, re-validate (max 3 rounds)

After ALL tasks in a wave are Thor-validated:

4. **Thor per-wave**: `plan-db.sh validate-wave {wave_db_id}`
5. **Wave merge**: `wave-worktree.sh merge {plan_id} {wave_db_id}` → auto-commit + rebase onto main + push (force-with-lease) + PR + CI + review comments check + squash merge to main
6. **If merge blocked (unresolved PR comments)**: Invoke `Task(subagent_type='pr-comment-resolver')` with PR number. After resolution, retry `wave-worktree.sh merge`. Max 3 rounds.
7. **Wave cleanup (NON-NEGOTIABLE)**: After merge succeeds, verify ALL artifacts are cleaned:
   - `session-reaper.sh --max-age 0` (kill orphan processes)
   - `git worktree list` (no stale worktrees for this wave)
   - `git branch | grep plan/{plan_id}` (wave branch deleted)
   - Wave DB status = `done`
8. **Proceed to next wave**: Only after merge + cleanup succeeds

## Plan Closure Checklist (NON-NEGOTIABLE)

A plan is NOT done until ALL of the following are verified:

```bash
session-reaper.sh --max-age 0           # No orphan processes
git worktree list                        # Only main worktree
git branch | grep plan/                  # No stale plan branches
# For remote repos: all PRs merged/closed
```

**Leaving behind worktrees, branches, orphan processes, or open PRs = VIOLATION.**

**Why**: Task executors may not clean up. The coordinator is the single source of truth for plan progress and system hygiene.

## Resource Awareness (36GB Machine)

| Factor             | Impact                                                | Mitigation                                        |
| ------------------ | ----------------------------------------------------- | ------------------------------------------------- |
| Parallel executors | ~800MB-1.5GB each (claude + subprocess)               | Hard cap 5 concurrent                             |
| Microsoft Defender | Real-time scan on every file write (~700MB + 80% CPU) | Exclude `~/GitHub` worktrees in Defender          |
| Spotlight indexing | `mds_stores` ~1.5GB during reindex                    | Already excluded `~/GitHub`, `~/.claude`, `~/tmp` |
| Orphan processes   | pytest/node can grow 500MB-1.5GB if abandoned         | Reaper every 120s + post-task reap                |
| Swap threshold     | >10GB swap = system instability                       | Pre-spawn gate blocks at 10GB                     |

## Native Worktree Isolation (v2.1.50+)

`Task` tool supports `isolation: "worktree"` — subagents get an isolated git worktree automatically:

- Reduces manual `cd`/`pwd`/verify overhead for each agent
- `WorktreeCreate` hook: auto-provisions isolated branch on spawn
- `WorktreeRemove` hook: auto-cleans worktree on agent exit
- Combine with `task-executor` for full isolation without manual setup

```yaml
Task(subagent_type="task-executor", isolation="worktree", ...)
```

## Agent Type for Task Execution

**ALWAYS use `task-executor` subagent_type** when launching task agents. It has:

- plan-db.sh integration (auto-updates status)
- TDD workflow (RED → GREEN → REFACTOR)
- Worktree guard (prevents work on main)
- File locking (prevents conflicts)

**NEVER use `general-purpose`** for plan task execution. It lacks plan-db awareness and will not update task status.
