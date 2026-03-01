<!-- v2.5.0 | 01 Mar 2026 | Copilot CLI Thor validation pattern (anti-self-validation) -->

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

## Token Tracking (MANDATORY for task-executor)

Token tracking is **automatic** at `validate-task` time: `tasks.tokens` is populated by summing `token_usage` entries in `[task.started_at, task.completed_at]` for the task's project (DB time-window join, no file reads). Real API counts from `token_usage` are preferred over `--tokens N` estimates; if no data in the window, existing value is preserved.

| Executor                          | How tokens land in `token_usage`                          | Timing vs validate-task                            |
| --------------------------------- | --------------------------------------------------------- | -------------------------------------------------- |
| Claude task-executor subagent     | Stop hook (`session-end-tokens.sh`) per subagent session  | Before validate-task ✓                             |
| Copilot CLI (copilot-worker.sh)   | sessionEnd hook (`session-tokens.sh`) per copilot session | Before validate-task ✓                             |
| Direct API (delegate.sh)          | `delegate-utils.sh` writes per call                       | Before validate-task ✓                             |
| In-session executor (no subagent) | Stop hook fires at full session end                       | After validate-task — pass `--tokens N` explicitly |

## Model Escalation Strategy

| Agent Type                 | Default                         | Escalation Rule                                          |
| -------------------------- | ------------------------------- | -------------------------------------------------------- |
| Task Executor              | `gpt-5.3-codex` (GPT-5.3-Codex) | → `claude-opus-4.6` if cross-cutting or architectural    |
| Coordinator (Standard)     | `claude-sonnet-4.6` (`sonnet`)  | → `claude-opus-4.6` (`opus`) if >3 concurrent tasks      |
| Coordinator (Max Parallel) | `claude-opus-4.6` (`opus`)      | Required for unlimited parallelization                   |
| Coordinator (Agent Teams)  | `claude-sonnet-4.6` (`sonnet`)  | → `claude-opus-4.6` (`opus`) for large team coordination |
| Validator (Thor)           | `claude-sonnet-4.6` (`sonnet`)  | No escalation                                            |

**Model naming note**:

- Claude API shorthand (`sonnet` / `opus` / `haiku`) is an alias layer.
- Copilot Task `model:` must use full model IDs (for example `gpt-5.3-codex`, `claude-sonnet-4.6`).

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
   **Pre-merge gate (NON-NEGOTIABLE)**: `pr-ops.sh ready {pr}` MUST show 0 blockers. Requires: (a) CI green on PR branch, (b) zero unresolved review threads. `wave-worktree.sh merge` enforces this automatically and BLOCKS if either fails.
   5b. **Post-merge CI + Deployment (BLOCKING — NON-NEGOTIABLE)**: After squash merge to main, coordinator MUST verify BOTH:
   - CI on main: `ci-watch.sh [branch] --sha {merge_sha}` → MUST reach SUCCESS. If FAIL → coordinator flags, does NOT close wave until fixed.
   - Deployment: `service-digest.sh deploy` → MUST show deployment COMPLETE (not just triggered). Wave is NOT done until deployment status = success/complete.
     Wave stays in `merging` state until both CI and deployment confirm green. Closing a wave with pending/failed main CI or incomplete deployment = VIOLATION.
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

## Copilot CLI Thor Validation (NON-NEGOTIABLE — Anti-Self-Validation)

**Self-validation = executor calls `validate-task ... thor` directly = VIOLATION.**
Same LLM has confirmation bias from implementation context. Fresh context reduces but does not eliminate bias.

**3-Layer Protection (all layers required):**

| Layer | Mechanism                                                                           | Bypassable?                       |
| ----- | ----------------------------------------------------------------------------------- | --------------------------------- |
| 1     | `plan-db-safe.sh` guards (time, git-diff, verify cmds)                              | NO — deterministic                |
| 2     | Independent validator in fresh context window                                       | Partially — same model, no memory |
| 3     | SQLite trigger `enforce_thor_done` (submitted→done only via validated_by whitelist) | NO — DB enforced                  |

**Correct Copilot CLI flow:**

```bash
# 1. Execute inline
# (Copilot edits files directly — faster than spawning copilot-worker subprocess)

# 2. Submit with mechanical guards (NON-BYPASSABLE)
plan-db-safe.sh update-task {id} done "summary"   # → status: submitted

# 3. Independent validation in FRESH context (NOT self-validation)
task(agent_type="validate", prompt="THOR PER-TASK | Plan:{plan_id} | Task:{task_id} | verify:{criteria}")
#   → If PASS:  plan-db.sh validate-task {id} {plan_id} thor   (submitted → done)
#   → If FAIL:  fix, re-submit, re-validate (max 3 rounds)
```

**Why fresh context matters**: `context_isolation: true` on both `task-executor` and `thor` agents means the validator has NO memory of the implementation phase. It reads files directly, runs verify commands independently, and cannot be biased by the executor's summary framing.

**copilot-worker.sh**: Must use `task(agent_type="validate")` for Thor, never direct `validate-task`. Layer 1 (plan-db-safe.sh) + Layer 3 (SQLite trigger) remain intact regardless.
