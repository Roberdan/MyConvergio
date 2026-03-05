---
name: task-executor-selfheal
description: Self-healing module for task-executor. Auto-diagnose, auto-fix, engage specialists.
version: "1.0.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — not directly invocable"]
model: sonnet
tools: "All tools"
---

# Self-Healing Module

> Referenced by task-executor.md Phase 3.8. Do not invoke directly.

## When to Trigger

Activate self-healing when ANY of these occur during Phase 2-3:

| Trigger               | Condition                                                           |
| --------------------- | ------------------------------------------------------------------- |
| Test failure persists | Same test fails after 2 implementation attempts                     |
| Build failure         | `ci-summary.sh` or build command exits non-zero                     |
| Import/module error   | `ModuleNotFoundError`, `Cannot find module`, `ERR_MODULE_NOT_FOUND` |
| Type error cascade    | >5 type errors from a single change                                 |
| Dependency conflict   | Version mismatch, peer dependency warnings                          |
| Permission/env error  | `EACCES`, `EPERM`, missing env var                                  |
| Timeout               | Command exceeds timeout threshold                                   |

## Phase 3.8: Self-Healing Protocol

### Step 1: Classify Failure

```bash
# Capture last error output (already in Bash result)
# Classify into category:
```

| Category         | Pattern                                             | Auto-Fix                                       |
| ---------------- | --------------------------------------------------- | ---------------------------------------------- |
| `missing_dep`    | `ModuleNotFoundError`, `Cannot find module`         | `npm install` / `pip install` in worktree      |
| `type_error`     | `TS\d+:`, `TypeError`, `Type.*not assignable`       | Read error file, fix types, re-run             |
| `import_path`    | `relative import`, `Cannot resolve`, `No such file` | Check actual file paths, fix imports           |
| `config_missing` | `ENOENT.*\.env`, `Missing.*config`, `KEY_NOT_FOUND` | Copy `.env.example` or create from template    |
| `port_conflict`  | `EADDRINUSE`, `address already in use`              | Kill process on port, retry                    |
| `schema_drift`   | `column.*does not exist`, `relation.*not found`     | Run migrations, re-seed                        |
| `stale_lock`     | `ELOCKED`, `resource busy`, `lock.*held`            | `file-lock.sh cleanup --max-age 1`             |
| `memory_oom`     | `JavaScript heap`, `MemoryError`, `Killed`          | Reduce test scope, retry with `--maxWorkers=1` |
| `unknown`        | None of the above                                   | Engage specialist agent                        |

### Step 2: Auto-Fix (Known Patterns)

Apply fix for classified category. ONE attempt per category. Track in `self_heal_log`:

```bash
# Example: missing_dep
cd "{worktree}" && npm install 2>&1 | tail -5
# Re-run failing command
```

### Step 3: Engage Specialist (If Auto-Fix Fails)

If auto-fix fails OR category is `unknown`, delegate to specialist:

```
Task(subagent_type="dario-debugger",
  prompt="Debug failure in {worktree_path}.\n
    Task: {task_id} — {title}\n
    Error: {last_error_output}\n
    Files: {target_files}\n
    What I tried: {self_heal_log}\n
    Find root cause and suggest fix. Do NOT edit files — report only.")
```

**Agent selection**:

| Failure complexity            | Agent                        | Why                      |
| ----------------------------- | ---------------------------- | ------------------------ |
| Single clear error            | `dario-debugger`             | Systematic root cause    |
| Multiple competing hypotheses | `adversarial-debugger`       | 3 parallel hypotheses    |
| Performance/timeout           | `otto-performance-optimizer` | Profiling + optimization |

### Step 4: Apply Specialist Recommendation

Read specialist output. Apply recommended fix. Re-run tests/build.

### Step 5: Escalation (Last Resort)

If specialist fix also fails (2 specialist rounds max):

1. **Mark `blocked`** with structured failure report
2. **Notify coordinator** via output data:

```bash
plan-db-safe.sh update-task {db_task_id} blocked "Self-healing exhausted" \
  --output-data '{
    "failure_category": "unknown",
    "attempts": [
      {"approach": "auto-fix: npm install", "result": "still failing"},
      {"approach": "dario-debugger: suggested X", "result": "applied, still failing"}
    ],
    "error_summary": "Brief description",
    "suggested_action": "Manual investigation needed at {file}:{line}"
  }'
```

## Self-Healing Budget

| Resource                       | Limit                               |
| ------------------------------ | ----------------------------------- |
| Auto-fix attempts per category | 1                                   |
| Specialist agent invocations   | 2 (total, not per category)         |
| Extra turns consumed           | Max 8 (beyond normal workflow)      |
| Total self-healing time        | If past turn 25, skip to escalation |

## Decision Tree

```
Failure detected
├─ Classified? → Auto-fix (1 attempt)
│  ├─ Fixed → Resume normal workflow
│  └─ Still failing → Engage specialist
│     ├─ Specialist fix works → Resume normal workflow
│     └─ Specialist fix fails → 2nd specialist (different agent)
│        ├─ Fixed → Resume
│        └─ Failed → Mark blocked with full report
└─ Unknown category → Engage specialist directly (skip auto-fix)
```

## Coordinator Integration

When self-healing succeeds, include in task output:

```bash
--output-data '{"self_healed": true, "category": "missing_dep", "fix": "npm install added missing package"}'
```

Dashboard health detection uses this to track self-healing frequency per plan.

---

**v1.0.0** (2026-03-05): Initial self-healing module — auto-fix, specialist engagement, structured escalation
