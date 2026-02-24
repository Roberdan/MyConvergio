<!-- v2.1.0 | 24 Feb 2026 | Added First Principle + Gate 10 -->

# Execution Optimization

## First Principle: Minimize Errors, Maximize Correctness

The most effective token optimization is preventing rework. Every undetected error triggers a correction cycle (debug + fix + re-validation + re-review) costing 50-100K+ tokens. Proactive verification costs 10-20K but eliminates these cycles.

| Strategy                  | Upfront Cost     | Prevents                   |
| ------------------------- | ---------------- | -------------------------- |
| TDD (Gate 8)              | ~5K tokens/task  | Debugging cycles           |
| Thor per-task (Gates 1-9) | ~10K tokens/task | Errors before wave merge   |
| Cross-Review (Gate 10)    | ~15K tokens/wave | Cross-file inconsistencies |
| ADR compliance (Gate 9)   | ~3K tokens/task  | Architectural regressions  |

**ROI**: A missed error costs 3-5x more to fix than proactive verification. Gate 10 exists because Plan 209 proved per-task validation (Gates 1-9) misses holistic issues — 3 cross-file inconsistencies passed 13 task validations, requiring a full additional review session to resolve.

**Rule**: Never skip verification gates to "save tokens." The cheapest token is the one not spent on rework.

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
| Task Executor              | gpt-5.3-codex | → opus if cross-cutting or architectural |
| Coordinator (Standard)     | sonnet        | → opus if >3 concurrent tasks            |
| Coordinator (Max Parallel) | **opus**      | Required for unlimited parallelization   |
| Validator (Thor)           | opus          | No escalation                            |

## Parallelization Modes (User Choice)

**Standard Mode** (default):

- Max 3 concurrent task-executors
- Sonnet coordination
- Cost: $ moderate, Speed: ⚡⚡ normal

**Max Parallel Mode** (optional):

- Unlimited concurrent task-executors
- **Opus coordination** (required)
- Cost: $$$ high, Speed: ⚡⚡⚡⚡ (3-5x faster)
- Use case: Urgent deadlines, large plans (10+ tasks)

**Selection**: Planner asks user after plan approval, before execution starts.

## Coordinator Post-Task Protocol (MANDATORY)

After each task-executor completes, the coordinator MUST:

1. **Verify DB update**: `sqlite3 ~/.claude/data/dashboard.db "SELECT status FROM tasks WHERE id={db_task_id};"` — if not `done`, run `plan-db.sh update-task {db_task_id} done "notes"`
2. **Thor per-task**: `plan-db.sh validate-task {db_task_id} {plan_id}`
3. **If Thor FAILS**: fix issue, re-validate (max 3 rounds)

After ALL tasks in a wave are Thor-validated:

4. **Thor per-wave**: `plan-db.sh validate-wave {wave_db_id}`
5. **Gate 10 Cross-Review**: `cross-review.sh {plan_id} {wave_db_id} --provider copilot` (auto-triggered by plan-db-safe.sh)
6. **Wave merge**: `wave-worktree.sh merge {plan_id} {wave_db_id}` → auto-commit + push + PR + CI + squash merge to main
7. **Proceed to next wave**: Only after merge succeeds

**Why**: Task executors (especially non-task-executor agents) may not update plan-db or run Thor. The coordinator is the single source of truth for plan progress. Commit per-wave (not per-task) because Thor wave validation is the quality gate.

## Agent Type for Task Execution

**ALWAYS use `task-executor` subagent_type** when launching task agents. It has:

- plan-db.sh integration (auto-updates status)
- TDD workflow (RED → GREEN → REFACTOR)
- Worktree guard (prevents work on main)
- File locking (prevents conflicts)

**NEVER use `general-purpose`** for plan task execution. It lacks plan-db awareness and will not update task status.
